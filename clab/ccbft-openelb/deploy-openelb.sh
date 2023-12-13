#!/usr/bin/env bash
set -e

REPO_ROOT=$(dirname "${BASH_SOURCE[0]}")/..
source "${REPO_ROOT}"/hack/util.sh

METALLB_ROOT=${FILE_ROOT:-"$REPO_ROOT/third_party/metallb"}
FRR_ROOT=${FRR_ROOT:-"$REPO_ROOT/third_party/metallb/frr"}

STAR_CLUSTER=${STAR_CLUSTER:-"star-cluster"}
PLANET_CLUSTER_PREFIX=${PLANET_CLUSTER_PREFIX:-"planet-cluster"}
PLANET_CLUSTER_NUM=${PLANET_CLUSTER_NUM:-3}
KUBECONFIG=${KUBECONFIG:-"/$USER/.kube/config"}

# 部署metallb步骤

util::log_info "0. 启动frr-upstream"
arr_ip=()
for ((i = 0; i < $PLANET_CLUSTER_NUM; i++)); do
    cluster_name="${PLANET_CLUSTER_PREFIX}-$i"
    util::log_info "cluster_name: $cluster_name"
    ips=`kubectl get nodes -lsubmariner.io/gateway=true -o=jsonpath={.items[*].status.addresses} --kubeconfig "$cluster_name".kubeconfig | jq -r '.[] | select(.type=="InternalIP").address'`

    array=(${ips// / })
    arr_ip=(${arr_ip[@]} ${array[@]})
done

path=`pwd` # TODO(lql): docker指定路径提示只能够使用绝对路径
docker run -d -v "$path/third_party/metallb/frr":/etc/frr:Z --network=kind --name frr-upstream --privileged quay.io/frrouting/frr:latest
# 等待的必要性: CI上有时会出现容器不存在的情况
for ((i = 0; i < 100; i ++)); do
  frr_ip=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' frr-upstream || true`
  if [ "$frr_ip" ]; then
      echo "frr_upstream_ip:" $frr_ip
      break
  fi
done

cat > frr.conf <<EOF
frr version 8.2.0_git
frr defaults traditional
hostname frr-upstreams
!
debug bgp updates
debug bgp neighbor
debug zebra nht
debug bgp nht
debug bfd peer
log file /tmp/frr.log debugging
log timestamp precision 3
!
interface virbr2
 ip address frr_upstream_ip/frr_upstream_cnt
!
router bgp 64512
 bgp router-id frr_upstream_ip
 timers bgp 3 15
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 no bgp network import-check
 neighbor metallb peer-group
 neighbor metallb remote-as 64500
EOF

for ip in "${arr_ip[@]}"; do

cat >> frr.conf <<EOF
 neighbor $ip peer-group metallb
 neighbor $ip bfd
EOF
done

cat >> frr.conf <<EOF
!
 address-family ipv4 unicast
EOF

for ip in "${arr_ip[@]}"; do
ip=`echo $ip | sed 's/\"//g'`
cat >> frr.conf <<EOF
 neighbor $ip next-hop-self
 neighbor $ip activate
EOF
done

cat >> frr.conf <<EOF
 exit-address-family
!
line vty
EOF

sed -i "s/frr_upstream_ip/$frr_ip/g" frr.conf
sed -i "s/frr_upstream_cnt/24/g" frr.conf
# fcc.conf文件构造完成
mv -f frr.conf "$FRR_ROOT"/frr.conf
docker restart frr-upstream


util::log_info "2. 修改config.yaml(用于cluster中的frr与frr-upstream之间通信)"
sed -i "s/peer-address:.*$/peer-address: $frr_ip/g" "$METALLB_ROOT"/config.yaml

util::log_info "3. 在star部署controller(与planet中的speaker通信)"
kubectl create ns metallb-system --kubeconfig $KUBECONFIG --context=kind-"$STAR_CLUSTER"
kubectl annotate ns metallb-system starNodeSchedule="true"
kubectl label node "$STAR_CLUSTER-control-plane" node-role.kubernetes.io/master=
kubectl apply -f "$METALLB_ROOT"/metallb-controller.yaml --kubeconfig $KUBECONFIG --context=kind-"$STAR_CLUSTER"
kubectl apply -f "$METALLB_ROOT"/config.yaml --kubeconfig $KUBECONFIG --context=kind-"$STAR_CLUSTER"

util::log_info "4. 在planet部署speaker(与star中的controller通信)"
for ((i = 0; i < $PLANET_CLUSTER_NUM; i++)); do
    cluster_name=${PLANET_CLUSTER_PREFIX}-"$i"

    kind load docker-image quay.io/frrouting/frr:stable_7.5 --name=$cluster_name
    kind load docker-image mizargalaxy/metallb-speaker:v0.12.1 --name=$cluster_name
    kind load docker-image mizargalaxy/metallb-controller:v0.12.5 --name=$cluster_name

    kubectl create ns metallb-system --kubeconfig="$cluster_name".kubeconfig
    kubectl apply -f "$METALLB_ROOT"/metallb-frr.yaml --kubeconfig="$cluster_name".kubeconfig
    kubectl apply -f "$METALLB_ROOT"/config.yaml --kubeconfig="$cluster_name".kubeconfig
    kubectl apply -f "$METALLB_ROOT"/memberlist.yaml --kubeconfig="$cluster_name".kubeconfig
done

# 外部流量入口
ip route add 10.10.192.0/24 via "$frr_ip"

util::log_success "部署metallb完成 🤩"

util::log_info "测试metallb"

set +e
cnt=${#arr_ip[@]}
for ((i = 0; i < 60; i ++)); do
    is_fail=0
    ip_str=`docker exec frr-upstream vtysh -c "show ip bgp neighbor" | grep -E "remote router ID" | awk '{print$7}'`
    ip_new=(${ip_str//,/})

    for ((j = 0; j < $cnt; j++)); do
        if [ "${ip_new[$j]}" == "${arr_ip[$j]}" ]; then
            vis_arr[$j]=1
        else
            vis_arr[$j]=0
        fi
    done

    info_arr=()
    info_cnt=0
    for ((j = 0; j < $cnt; j++)); do
        if [ ${vis_arr[$j]} -eq 0 ]; then
            is_fail=1
            info_arr[$info_cnt]=${arr_ip[$j]}
            let info_cnt++
        fi
    done

    printf "\r %s 暂时无法连接, 测试进度 %d / 60" "${info_arr[*]}" $i

    if [ ${is_fail} -eq 0 ]; then
        break
    fi
    sleep 1
done

if [ $is_fail -eq 0 ]; then
    util::log_success "metallb测试成功"
else
     util::log_error "metallb测试失败"
     exit 1
fi

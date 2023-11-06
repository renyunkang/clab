#!/usr/bin/env bash
set -e

cluster_name="openelb"
# 部署metallb步骤
echo "0. 启动frr-upstream"
ips=`kubectl get nodes -o=jsonpath={.items[*].status.addresses} | jq -r '.[] | select(.type=="InternalIP").address'`
array=(${ips// / })
arr_ip=(${arr_ip[@]} ${array[@]})

path=`pwd` # TODO(lql): docker指定路径提示只能够使用绝对路径
docker run -d -v "$path/frr":/etc/frr:Z --network=kind --name frr-upstream --privileged frrouting/frr:latest
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
router bgp 64500
 bgp router-id frr_upstream_ip
 timers bgp 3 15
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 no bgp network import-check
 neighbor metallb peer-group
 neighbor metallb remote-as 64512
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
mv -f frr.conf "$path"/frr/frr.conf
docker restart frr-upstream


echo "2. 修改config.yaml(用于cluster中的frr与frr-upstream之间通信)"
sed -i "s/neighborAddress:.*$/neighborAddress: $frr_ip/g" "$path"/bgp.yaml

echo "3. 在star部署controller(与planet中的speaker通信)"
kind load docker-image kubesphere/openelb-speaker:refactor --name=$cluster_name
kind load docker-image kubesphere/openelb-controller:refactor --name=$cluster_name
kubectl apply -f "$path"/openelb.yaml
kubectl apply -f "$path"/bgp.yaml

# 外部流量入口
ip route add 10.10.100.0/24 via "$frr_ip"

echo "部署openelb完成 🤩"

echo "测试openelb"

set +e
cnt=${#arr_ip[@]}
for ((i = 0; i < 60; i ++)); do
    is_fail=0
    ip_str=`docker exec frr-upstream vtysh -c "show ip bgp neighbor" | grep -E "BGP neighbor is" | awk '{print$4}'`
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
    echo "openelb测试成功"
else
     echo "openelb测试失败"
     exit 1
fi

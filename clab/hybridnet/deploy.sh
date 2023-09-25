
kubectl label node hybridnet-control-plane vlan/leaf=leaf1
kubectl label node hybridnet-worker vlan/leaf=leaf1
kubectl label node hybridnet-worker2 vlan/leaf=leaf1
kubectl label node hybridnet-worker3 vlan/leaf=leaf1
kubectl label node hybridnet-worker4 vlan/leaf=leaf1
kubectl label node hybridnet-worker5 vlan/leaf=leaf2
kubectl label node hybridnet-worker6 vlan/leaf=leaf2
kubectl label node hybridnet-worker7 vlan/leaf=leaf2
kubectl label node hybridnet-worker8 vlan/leaf=leaf2

cat << EOF | kubectl apply -f -
apiVersion: networking.alibaba.com/v1
kind: Network
metadata:
  name: vlan-leaf1
spec:
  type: Underlay
  mode: VLAN
  nodeSelector:
    vlan/leaf: "leaf1"
---
apiVersion: networking.alibaba.com/v1
kind: Subnet
metadata:
  name: subnet-10
spec:
  network: vlan-leaf1
  netID: 10
  range:
    cidr: 10.10.10.0/24
    version: "4"
    gateway: "10.10.10.1"
    start: "10.10.10.100"
    end: "10.10.10.250"

---
apiVersion: networking.alibaba.com/v1
kind: Subnet
metadata:
  name: subnet-11
spec:
  network: vlan-leaf1
  netID: 11
  range:
    cidr: 10.10.11.0/24
    version: "4"
    gateway: "10.10.11.1"
    start: "10.10.11.100"
    end: "10.10.11.250"


---
apiVersion: networking.alibaba.com/v1
kind: Network
metadata:
  name: vlan-leaf2
spec:
  type: Underlay
  mode: VLAN
  nodeSelector:
    vlan/leaf: "leaf2"

---
apiVersion: networking.alibaba.com/v1
kind: Subnet
metadata:
  name: subnet-21
spec:
  network: vlan-leaf2
  netID: 21
  range:
    cidr: 10.11.21.0/24
    version: "4"
    gateway: "10.11.21.1"
    start: "10.11.21.100"
    end: "10.11.21.250"

---
apiVersion: networking.alibaba.com/v1
kind: Subnet
metadata:
  name: subnet-22
spec:
  network: vlan-leaf2
  netID: 22
  range:
    cidr: 10.11.22.0/24
    version: "4"
    gateway: "10.11.22.1"
    start: "10.11.22.100"
    end: "10.11.22.250"
EOF


kubectl create ns project-1
kubectl annotate ns project-1 networking.alibaba.com/specified-network=vlan-leaf1
kubectl create ns project-2
kubectl annotate ns project-2 networking.alibaba.com/specified-network=vlan-leaf2
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: netools
  name: netools
  namespace: project-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: netools
  template:
    metadata:
      labels:
        app: netools
    spec:
      containers:
      - image: rykren/netools:latest
        imagePullPolicy: IfNotPresent
        name: container
        ports:
        - containerPort: 80
          name: http-0
          protocol: TCP
      restartPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: netools
  name: netools
  namespace: project-1
spec:
  internalTrafficPolicy: Cluster
  ports:
  - name: http-80
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: netools
  sessionAffinity: None
  type: ClusterIP

EOF

cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: netools
  name: netools
  namespace: project-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: netools
  template:
    metadata:
      labels:
        app: netools
    spec:
      containers:
      - image: rykren/netools:latest
        imagePullPolicy: IfNotPresent
        name: container
        ports:
        - containerPort: 80
          name: http-0
          protocol: TCP
      restartPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: netools
  name: netools
  namespace: project-2
spec:
  internalTrafficPolicy: Cluster
  ports:
  - name: http-80
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: netools
  sessionAffinity: None
  type: ClusterIP

EOF

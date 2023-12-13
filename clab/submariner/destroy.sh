kind delete cluster --name=broker
kind delete cluster --name=c1
kind delete cluster --name=c2

rm  ~/.kube/config-1
rm  ~/.kube/config-2
rm  ~/.kube/config-3

sed -i '/# begin kind cluster-broker/,/# end kind cluster-broker/d' ~/.bash_aliases
sed -i '/# begin kind cluster-c1/,/# end kind cluster-c1/d' ~/.bash_aliases
sed -i '/# begin kind cluster-c2/,/# end kind cluster-c2/d' ~/.bash_aliases

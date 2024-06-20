
kind delete cluster --name=kse
kind delete cluster --name=kse4

rm  /root/.kube/config-3.5
rm  /root/.kube/config-4.0

sed -i '/# begin kind cluster-kse/,/# end kind cluster-kse/d' ~/.bash_aliases
sed -i '/# begin kind cluster-kse4/,/# end kind cluster-kse4/d' ~/.bash_aliases

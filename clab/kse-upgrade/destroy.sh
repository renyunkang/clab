
kind delete cluster --name=kse
kind delete cluster --name=kse2

rm  /root/.kube/config-3.5
rm  /root/.kube/config-4.0

sed -i '/# begin kind cluster-kse/,/# end kind cluster-kse/d' ~/.bash_aliases
sed -i '/# begin kind cluster-kse2/,/# end kind cluster-kse2/d' ~/.bash_aliases

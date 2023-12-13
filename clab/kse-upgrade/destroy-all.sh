
kind delete cluster --name=kse
kind delete cluster --name=kse2
kind delete cluster --name=kse3

rm  /root/.kube/config-1
rm  /root/.kube/config-2
rm  /root/.kube/config-3

sed -i '/# begin kind cluster-kse/,/# end kind cluster-kse/d' ~/.bash_aliases
sed -i '/# begin kind cluster-kse2/,/# end kind cluster-kse2/d' ~/.bash_aliases
sed -i '/# begin kind cluster-kse3/,/# end kind cluster-kse3/d' ~/.bash_aliases

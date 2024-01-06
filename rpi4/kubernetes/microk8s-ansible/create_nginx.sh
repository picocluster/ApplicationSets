microk8s.kubectl create deployment nginx --image=nginx --port=80 --replicas=3
microk8s.kubectl expose deployment nginx --port 80
sleep 60
microk8s.kubectl get endpoints nginx

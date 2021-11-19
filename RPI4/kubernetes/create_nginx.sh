#kubectl run nginx --image=nginx --port=80
kubectl create deployment nginx --image=nginx --port=80 --replicas=3
kubectl expose deployment nginx --port 80
sleep 15
kubectl get endpoints nginx

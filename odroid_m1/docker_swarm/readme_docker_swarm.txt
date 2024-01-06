Docker Swarm is installed and running already. You can list the nodes n the swarm with the following command:

sh swarm_status.sh
You'll see output that looks like this:
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS
4wisbtg3helyw5vttchsy68m8 *   pc0                 Ready               Active              Leader
iojq7ffm87mwocvektuiw1vyv     pc1                 Ready               Active              
zmbpf3lrcqawy79eurnq7o8de     pc2                 Ready               Active              
k0o0jaamqbj5p4prc9zxsvq6v     pc3                 Ready               Active              
u2774phf3ajkzotpr28gehh8s     pc4                 Ready               Active       


You can run your first service by running the command:
sh create_visualizer_service.sh 
0o7zvfk8k19ioa3out09t5iqt
overall progress: 1 out of 1 tasks 
1/1: running   [==================================================>] 
verify: Service converged 

It will take a few minutes to create the service.

If you run the following command, you can see that the service has started:
sh list_services.sh

You should get output that looks like this:
ID                  NAME                MODE                REPLICAS            IMAGE                              PORTS
0o7zvfk8k19i        viz                 replicated          1/1                 alexellis2/visualizer-arm:latest   *:8080->8080/tcp

You can now use your web browser to go to http://pc0:8080 or http://10.1.10.240:8080.

Contact support@picocluster.com if you need any help.

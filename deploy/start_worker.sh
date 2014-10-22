#!/bin/sh

master=$1
worker=$2
private_ip=$3

worker_dir=/home/$worker

rm -r $worker_dir
mkdir $worker_dir

# get default configurations from etcd server
to_publish=$(etcdctl get /etcd_spark/$master/$worker/to_publish)
datanode_port=$(etcdctl get /etcd_spark/$master/$worker/DATANODE_PORT)
spark_env=$(etcdctl get /etcd_spark/$master//$worker/spark_env)
worker_ui=$(etcdctl get /etcd_spark/$master/$worker/WORKER_UI)
worker_port=$(etcdctl get /etcd_spark/$master/$worker/WORKER_PORT)
log4j=$(etcdctl get /etcd_spark/$master/log4j)

# saving into files
echo $log4j > $worker_dir/log4j.properties
echo $spark_env > $worker_dir/spark-env.sh
echo "export SPARK_WORKER_PORT=$worker_port" >> $worker_dir/spark-env.sh

# First port in to_publish worker UI port, so it should be published to 0.0.0.0
# Therefore $private_ip is not attached at the front. Other ports are published
# to private network.
count=0
publish_args=""
for i in ${to_publish[@]}
do
    if [ count == 0 ] ; then
        count=$(( count+1 ))
        publish_args="$publish_args -p $i:$i"
    fi
    publish_args="$publish_args -p $private_ip:$i:$i"
done

env_args="-e ETCD_ADDRESS=$ETCD_IP -e ETCD_PORT=$ETCD_PORT -e HOST_ADDRESS=$private_ip -e SPARK_WORKER_UI_PORT=$worker_ui -e DATANODE_PORT=$datanode_port"

# start docker container
docker run --name $worker -h $worker $publish_args $env_args -v $worker_dir:/home/run luckysahaf/spark-worker:1.1.0 $master

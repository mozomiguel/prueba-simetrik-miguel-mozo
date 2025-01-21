#!/bin/bash

wait_for_alb() {
    local NAMESPACE=$1
    local INGRESS_NAME=$2
    local TIMEOUT=600  # 10 minutes timeout
    local INTERVAL=20  # 20 seconds between checks
    local start_time=$(date +%s)

    echo "Waiting for ALB to be ready..."

    while true; do
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))
        
        if [ $elapsed_time -gt $TIMEOUT ]; then
            echo "Timeout waiting for ALB"
            return 1
        fi

        export ALB_ADDRESS=$(kubectl get ingress server-app-ingress -n server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
        
        if [ -n "$ALB_ADDRESS" ]; then
            echo "Found ALB address: $ALB_ADDRESS"
            ALB_STATE=$(aws elbv2 describe-load-balancers --names server-app-alb --query 'LoadBalancers[0].State.Code' --output text 2>/dev/null)
            if [ "$ALB_STATE" == "active" ]; then
                echo "ALB is active!"
                return 0
            else
                echo "ALB state is: $ALB_STATE"
            fi
        else
            echo "Waiting for ALB address... (${elapsed_time}s elapsed)"
        fi

        sleep $INTERVAL
    done
}

# Usage
wait_for_alb

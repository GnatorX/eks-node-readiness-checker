### Amazon EKS Node Readiness Checker

Amazon EKS node readinesss checker with AWS lambda.
This lambda hooks into Autoscaling group (ASG)'s lifecycle hooks <https://docs.aws.amazon.com/autoscaling/ec2/userguide/lifecycle-hooks.html> to ensure node is ready from Kubernetes (K8s)' perspective.

## Problem

When performing updates against node groups managed by AWS ASG within EKS, ASG can some times move too quickly causing down time on apps running on the cluster. The problem is that ASG watches when an EC2 starts up before moving on to terminating the next node. Since ASG doesn't confirm if the node is ready from K8s' perspective, it is possible that kubelet isn't completely set up on the node. Which means the node is not attached to EKS yet. It is also possible that pods on the node isn't in "Ready" state before ASG moves on to the next node. This could mean that the number of replicas for your application could be reduced during ASG update which could bring down or reduce your application's availability.

## Implementation

This project takes inspiration from <https://github.com/awslabs/amazon-eks-serverless-drainer>. It is a SAM lambda that uses the kubectl Lambda layer to interact with EKS cluster. The lambda requires the creation of launch lifecycle hook on all EKS node group's ASG <https://docs.aws.amazon.com/autoscaling/ec2/userguide/lifecycle-hooks.html#adding-lifecycle-hooks>. The lambda then hooks into that hook via AWS EventBridge. Once the lifecycle event triggers the lambda, the lambda watches for both Node and Pods status. It confirms that Node is in "Ready" state and all pods running on the node to be in "Running" state. Once those conditions are satisfied, the node will respond back to ASG to complete lifecycle action.

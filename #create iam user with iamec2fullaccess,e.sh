#create iam user with iamec2fullaccess,eksclusteraccess,cniaccess,workernodeaccess,ec2fullaccess,iamfullaccess && create customized inlina aws eks access resources* and read write execute delete access as well.

#create ec2 instance with t2.xlarge
#!/bin/bash
apt update -y
apt install openjdk-11-jdk -y
#installing jenkins
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
     https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
     echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
     https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
     /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get install jenkins

systemctl start jenkins
systemctl enable jenkins
#installing docker
apt update -y
apt install docker.io -y
sudo chmod 666 /var/run/docker.sock

docker run -d -p 9000:9000 sonarqube:lts-community




#install awscli for access the aws service
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws configure   #createthe aws credentials access and configure inthe awscli.

#root@ip-172-31-32-102:~# aws configure
#AWS Access Key ID [None]: AKIA2WGRTAHLKOFF4UEM
#AWS Secret Access Key [None]: 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
#Default region name [None]: ap-south-1
#Default output format [None]: table
#root@ip-172-31-32-102:~# aws configure list



#install kubectl for k8s
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/kubectl

chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin && kubectl version --short --client

#install eksctl for k8s
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp 
sudo mv /tmp/eksctl /usr/local/bin
eksctl version


#create eks cluster and workernodes thorugh cloduformationnstack template.
aws ec2 describe-availability-zones --region ap-south-1 #you will found the ap-south1a,1b,1c 
#>>note here i've created my ecn2 instance in mumbai region so ec2 instance and eks cluster all are i'm going to create in the ap-south-1 mumbai

eksctl create cluster --name=my-eks8 \
                      --region=ap-south-1
                      --zones=ap-south-1a,ap-south-1b \
                      --without-nodegroup

#Creating openID(Oauth2.0) connect for providing the IAM roles
eksctl utils associate-iam-oidc-provider \
        --region ap-south-1
        --cluster my-eks8-cluster \   #--cluster $cluster_name \
        --approve

eksctl create nodegroup --cluster=my-eks8 \
                        --region ap-south-1 \   #--region region-code \
                        --name=node2 \  #--name my-mng \
                        --node-type=t3.medium \
                        --nodes=2 \
                        --nodes-min=2 \
                        --nodes-max=3 \
                        --node-volume-size=20 \
                        --ssh-access \
                        --ssh-public-key mynewkeypair \
                        --managed \
                        --asg-access \
                        --external-dns-access \
                        --full-ecr-access \
                        --appmesh-access \
                        --alb-ingress-access 

eksctl create nodegroup --cluster=my-eks8 \
                        --region ap-south-1 \ 
                        --name=node2 \  
                        --node-type=t3.medium \
                        --nodes=2 \
                        --nodes-min=2 \
                        --nodes-max=3 \
                        --node-volume-size=20 \
                        --ssh-access \
                        --ssh-public-key mynewkeypair \
                        --managed \
                        --asg-access \
                        --external-dns-access \
                        --full-ecr-access \
                        --appmesh-access \
                        --alb-ingress-access

#now open the inbound traffic in additional securitygroup
    #>> goto eks8 cluster and select networking under security addtional secirituy group add rule inbound to allow all traffic or your rquired port.

#createservice account/ROLE/BIND-ROLE/Token




#install plugins in jenkins
#plugins --kubernetes
         # kubernetescli
          #docker
         # dockerpipeline
          #dockerbuild step
          #sonarqube scanner
#goto manage jenkins /tools/ configure sonar and docker to latest versions
#goto sonaqserver and create the token at administration/user-token/generate and store tokeninjenkins credentials as secretext
#provide the sonar url in jenkins system

#now its time to create service account.role &assign that role and create secrete for service accint
 #and generate a token
kubectl create namespace webapps

vi serviceaccount.yaml

apiVersion: v1
kind: ServiceAccount
metadata:
    name: jenkins
    namespace: webapps

kubectl apply -f serviceaccount.yaml

#apiVersion: rbac.authorization.k8s.io/v1     tis is the tempalate for creatinghte rbac
#kind: Role
#metadata:
 # namespace: webapps
  #name: app-role
#rules:
#- apiGroups: [""] # "" indicates the core API group4
 # resources: ["pods"]
  #verbs: ["get", "watch", "list"]

vi rbac.yaml

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: webapps
  name: app-role
rules:
  - apiGroups:
      - ""
      - apps
      - autoscaling
      - batch
      - extensions
      - policy
      - rbac.authorization.k8s.io
    resources:
      - pods
      - componentstatuses
      - configmaps
      - daemonsets
      - deployments
      - events
      - endpoints
      - horizontalpodautoscalers
      - ingress
      - jobs
      - limitranges
      - namespaces
      - nodes
      - pods
      - persistentvolumes
      - persistentvolumeclaims
      - resourcequotas
      - replicasets
      - replicationcontrollers
      - serviceaccounts
      - services
    verbs:
      - get
      - watch
      - create
      - update
      - patch
      - delete
      - list

kubectl apply -f rbac.yaml

vi roletoserviceaccount.yaml

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
  namespace: webapps
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-role
subjects:
  - namespace: webapps
    kind: ServiceAccount
    name: jenkins
#kubectl apply -f roletoserviceaccount.yaml

#generate token using service account inthe namespace
https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#create-token

---
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: mysecretname
  annotations:
    kubernetes.io/service-account.name: jenkins
#kubectl apply -f secret.yaml -n webapps


#decribe the secrets >>syntx kubectl describe secret secretname -n namespacename
kubectl describe secret mysecretname -n webapps



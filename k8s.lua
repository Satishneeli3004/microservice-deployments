eksctl create cluster --name=my-eks8 \
                      --region=ap-southeast-2
                      --zones=ap-southeast-1a,ap-southeast-1b \
                      --without-nodegroup

                      AWSTemplateFormatVersion: 2010-09-09
                      Description: >-
                        EKS cluster (dedicated VPC: true, dedicated IAM: true) [created and managed by
                        eksctl]
                      Mappings:
                        ServicePrincipalPartitionMap:
                          aws:
                            EC2: ec2.amazonaws.com
                            EKS: eks.amazonaws.com
                            EKSFargatePods: eks-fargate-pods.amazonaws.com
                          aws-cn:
                            EC2: ec2.amazonaws.com.cn
                            EKS: eks.amazonaws.com
                            EKSFargatePods: eks-fargate-pods.amazonaws.com
                          aws-iso:
                            EC2: ec2.c2s.ic.gov
                            EKS: eks.amazonaws.com
                            EKSFargatePods: eks-fargate-pods.amazonaws.com
                          aws-iso-b:
                            EC2: ec2.sc2s.sgov.gov
                            EKS: eks.amazonaws.com
                            EKSFargatePods: eks-fargate-pods.amazonaws.com
                          aws-us-gov:
                            EC2: ec2.amazonaws.com
                            EKS: eks.amazonaws.com
                            EKSFargatePods: eks-fargate-pods.amazonaws.com
                      Resources:
                        ClusterSharedNodeSecurityGroup:
                          Type: 'AWS::EC2::SecurityGroup'
                          Properties:
                            GroupDescription: Communication between all nodes in the cluster
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/ClusterSharedNodeSecurityGroup'
                            VpcId: !Ref VPC
                        ControlPlane:
                          Type: 'AWS::EKS::Cluster'
                          Properties:
                            AccessConfig:
                              AuthenticationMode: API_AND_CONFIG_MAP
                              BootstrapClusterCreatorAdminPermissions: true
                            KubernetesNetworkConfig:
                              IpFamily: ipv4
                            Name: my-eks8
                            ResourcesVpcConfig:
                              EndpointPrivateAccess: false
                              EndpointPublicAccess: true
                              SecurityGroupIds:
                                - !Ref ControlPlaneSecurityGroup
                              SubnetIds:
                                - !Ref SubnetPublicAPSOUTHEAST2C
                                - !Ref SubnetPublicAPSOUTHEAST2A
                                - !Ref SubnetPublicAPSOUTHEAST2B
                                - !Ref SubnetPrivateAPSOUTHEAST2C
                                - !Ref SubnetPrivateAPSOUTHEAST2A
                                - !Ref SubnetPrivateAPSOUTHEAST2B
                            RoleArn: !GetAtt 
                              - ServiceRole
                              - Arn
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/ControlPlane'
                            Version: '1.27'
                        ControlPlaneSecurityGroup:
                          Type: 'AWS::EC2::SecurityGroup'
                          Properties:
                            GroupDescription: Communication between the control plane and worker nodegroups
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/ControlPlaneSecurityGroup'
                            VpcId: !Ref VPC
                        IngressDefaultClusterToNodeSG:
                          Type: 'AWS::EC2::SecurityGroupIngress'
                          Properties:
                            Description: >-
                              Allow managed and unmanaged nodes to communicate with each other (all
                              ports)
                            FromPort: 0
                            GroupId: !Ref ClusterSharedNodeSecurityGroup
                            IpProtocol: '-1'
                            SourceSecurityGroupId: !GetAtt 
                              - ControlPlane
                              - ClusterSecurityGroupId
                            ToPort: 65535
                        IngressInterNodeGroupSG:
                          Type: 'AWS::EC2::SecurityGroupIngress'
                          Properties:
                            Description: Allow nodes to communicate with each other (all ports)
                            FromPort: 0
                            GroupId: !Ref ClusterSharedNodeSecurityGroup
                            IpProtocol: '-1'
                            SourceSecurityGroupId: !Ref ClusterSharedNodeSecurityGroup
                            ToPort: 65535
                        IngressNodeToDefaultClusterSG:
                          Type: 'AWS::EC2::SecurityGroupIngress'
                          Properties:
                            Description: Allow unmanaged nodes to communicate with control plane (all ports)
                            FromPort: 0
                            GroupId: !GetAtt 
                              - ControlPlane
                              - ClusterSecurityGroupId
                            IpProtocol: '-1'
                            SourceSecurityGroupId: !Ref ClusterSharedNodeSecurityGroup
                            ToPort: 65535
                        InternetGateway:
                          Type: 'AWS::EC2::InternetGateway'
                          Properties:
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/InternetGateway'
                        NATGateway:
                          Type: 'AWS::EC2::NatGateway'
                          Properties:
                            AllocationId: !GetAtt 
                              - NATIP
                              - AllocationId
                            SubnetId: !Ref SubnetPublicAPSOUTHEAST2C
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/NATGateway'
                        NATIP:
                          Type: 'AWS::EC2::EIP'
                          Properties:
                            Domain: vpc
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/NATIP'
                        NATPrivateSubnetRouteAPSOUTHEAST2A:
                          Type: 'AWS::EC2::Route'
                          Properties:
                            DestinationCidrBlock: 0.0.0.0/0
                            NatGatewayId: !Ref NATGateway
                            RouteTableId: !Ref PrivateRouteTableAPSOUTHEAST2A
                        NATPrivateSubnetRouteAPSOUTHEAST2B:
                          Type: 'AWS::EC2::Route'
                          Properties:
                            DestinationCidrBlock: 0.0.0.0/0
                            NatGatewayId: !Ref NATGateway
                            RouteTableId: !Ref PrivateRouteTableAPSOUTHEAST2B
                        NATPrivateSubnetRouteAPSOUTHEAST2C:
                          Type: 'AWS::EC2::Route'
                          Properties:
                            DestinationCidrBlock: 0.0.0.0/0
                            NatGatewayId: !Ref NATGateway
                            RouteTableId: !Ref PrivateRouteTableAPSOUTHEAST2C
                        PolicyCloudWatchMetrics:
                          Type: 'AWS::IAM::Policy'
                          Properties:
                            PolicyDocument:
                              Statement:
                                - Action:
                                    - 'cloudwatch:PutMetricData'
                                  Effect: Allow
                                  Resource: '*'
                              Version: 2012-10-17
                            PolicyName: !Sub '${AWS::StackName}-PolicyCloudWatchMetrics'
                            Roles:
                              - !Ref ServiceRole
                        PolicyELBPermissions:
                          Type: 'AWS::IAM::Policy'
                          Properties:
                            PolicyDocument:
                              Statement:
                                - Action:
                                    - 'ec2:DescribeAccountAttributes'
                                    - 'ec2:DescribeAddresses'
                                    - 'ec2:DescribeInternetGateways'
                                  Effect: Allow
                                  Resource: '*'
                              Version: 2012-10-17
                            PolicyName: !Sub '${AWS::StackName}-PolicyELBPermissions'
                            Roles:
                              - !Ref ServiceRole
                        PrivateRouteTableAPSOUTHEAST2A:
                          Type: 'AWS::EC2::RouteTable'
                          Properties:
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/PrivateRouteTableAPSOUTHEAST2A'
                            VpcId: !Ref VPC
                        PrivateRouteTableAPSOUTHEAST2B:
                          Type: 'AWS::EC2::RouteTable'
                          Properties:
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/PrivateRouteTableAPSOUTHEAST2B'
                            VpcId: !Ref VPC
                        PrivateRouteTableAPSOUTHEAST2C:
                          Type: 'AWS::EC2::RouteTable'
                          Properties:
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/PrivateRouteTableAPSOUTHEAST2C'
                            VpcId: !Ref VPC
                        PublicRouteTable:
                          Type: 'AWS::EC2::RouteTable'
                          Properties:
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/PublicRouteTable'
                            VpcId: !Ref VPC
                        PublicSubnetRoute:
                          Type: 'AWS::EC2::Route'
                          Properties:
                            DestinationCidrBlock: 0.0.0.0/0
                            GatewayId: !Ref InternetGateway
                            RouteTableId: !Ref PublicRouteTable
                          DependsOn:
                            - VPCGatewayAttachment
                        RouteTableAssociationPrivateAPSOUTHEAST2A:
                          Type: 'AWS::EC2::SubnetRouteTableAssociation'
                          Properties:
                            RouteTableId: !Ref PrivateRouteTableAPSOUTHEAST2A
                            SubnetId: !Ref SubnetPrivateAPSOUTHEAST2A
                        RouteTableAssociationPrivateAPSOUTHEAST2B:
                          Type: 'AWS::EC2::SubnetRouteTableAssociation'
                          Properties:
                            RouteTableId: !Ref PrivateRouteTableAPSOUTHEAST2B
                            SubnetId: !Ref SubnetPrivateAPSOUTHEAST2B
                        RouteTableAssociationPrivateAPSOUTHEAST2C:
                          Type: 'AWS::EC2::SubnetRouteTableAssociation'
                          Properties:
                            RouteTableId: !Ref PrivateRouteTableAPSOUTHEAST2C
                            SubnetId: !Ref SubnetPrivateAPSOUTHEAST2C
                        RouteTableAssociationPublicAPSOUTHEAST2A:
                          Type: 'AWS::EC2::SubnetRouteTableAssociation'
                          Properties:
                            RouteTableId: !Ref PublicRouteTable
                            SubnetId: !Ref SubnetPublicAPSOUTHEAST2A
                        RouteTableAssociationPublicAPSOUTHEAST2B:
                          Type: 'AWS::EC2::SubnetRouteTableAssociation'
                          Properties:
                            RouteTableId: !Ref PublicRouteTable
                            SubnetId: !Ref SubnetPublicAPSOUTHEAST2B
                        RouteTableAssociationPublicAPSOUTHEAST2C:
                          Type: 'AWS::EC2::SubnetRouteTableAssociation'
                          Properties:
                            RouteTableId: !Ref PublicRouteTable
                            SubnetId: !Ref SubnetPublicAPSOUTHEAST2C
                        ServiceRole:
                          Type: 'AWS::IAM::Role'
                          Properties:
                            AssumeRolePolicyDocument:
                              Statement:
                                - Action:
                                    - 'sts:AssumeRole'
                                  Effect: Allow
                                  Principal:
                                    Service:
                                      - !FindInMap 
                                        - ServicePrincipalPartitionMap
                                        - !Ref 'AWS::Partition'
                                        - EKS
                              Version: 2012-10-17
                            ManagedPolicyArns:
                              - !Sub 'arn:${AWS::Partition}:iam::aws:policy/AmazonEKSClusterPolicy'
                              - !Sub 'arn:${AWS::Partition}:iam::aws:policy/AmazonEKSVPCResourceController'
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/ServiceRole'
                        SubnetPrivateAPSOUTHEAST2A:
                          Type: 'AWS::EC2::Subnet'
                          Properties:
                            AvailabilityZone: ap-southeast-2a
                            CidrBlock: 192.168.128.0/19
                            Tags:
                              - Key: kubernetes.io/role/internal-elb
                                Value: '1'
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/SubnetPrivateAPSOUTHEAST2A'
                            VpcId: !Ref VPC
                        SubnetPrivateAPSOUTHEAST2B:
                          Type: 'AWS::EC2::Subnet'
                          Properties:
                            AvailabilityZone: ap-southeast-2b
                            CidrBlock: 192.168.160.0/19
                            Tags:
                              - Key: kubernetes.io/role/internal-elb
                                Value: '1'
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/SubnetPrivateAPSOUTHEAST2B'
                            VpcId: !Ref VPC
                        SubnetPrivateAPSOUTHEAST2C:
                          Type: 'AWS::EC2::Subnet'
                          Properties:
                            AvailabilityZone: ap-southeast-2c
                            CidrBlock: 192.168.96.0/19
                            Tags:
                              - Key: kubernetes.io/role/internal-elb
                                Value: '1'
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/SubnetPrivateAPSOUTHEAST2C'
                            VpcId: !Ref VPC
                        SubnetPublicAPSOUTHEAST2A:
                          Type: 'AWS::EC2::Subnet'
                          Properties:
                            AvailabilityZone: ap-southeast-2a
                            CidrBlock: 192.168.32.0/19
                            MapPublicIpOnLaunch: true
                            Tags:
                              - Key: kubernetes.io/role/elb
                                Value: '1'
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/SubnetPublicAPSOUTHEAST2A'
                            VpcId: !Ref VPC
                        SubnetPublicAPSOUTHEAST2B:
                          Type: 'AWS::EC2::Subnet'
                          Properties:
                            AvailabilityZone: ap-southeast-2b
                            CidrBlock: 192.168.64.0/19
                            MapPublicIpOnLaunch: true
                            Tags:
                              - Key: kubernetes.io/role/elb
                                Value: '1'
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/SubnetPublicAPSOUTHEAST2B'
                            VpcId: !Ref VPC
                        SubnetPublicAPSOUTHEAST2C:
                          Type: 'AWS::EC2::Subnet'
                          Properties:
                            AvailabilityZone: ap-southeast-2c
                            CidrBlock: 192.168.0.0/19
                            MapPublicIpOnLaunch: true
                            Tags:
                              - Key: kubernetes.io/role/elb
                                Value: '1'
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/SubnetPublicAPSOUTHEAST2C'
                            VpcId: !Ref VPC
                        VPC:
                          Type: 'AWS::EC2::VPC'
                          Properties:
                            CidrBlock: 192.168.0.0/16
                            EnableDnsHostnames: true
                            EnableDnsSupport: true
                            Tags:
                              - Key: Name
                                Value: !Sub '${AWS::StackName}/VPC'
                        VPCGatewayAttachment:
                          Type: 'AWS::EC2::VPCGatewayAttachment'
                          Properties:
                            InternetGatewayId: !Ref InternetGateway
                            VpcId: !Ref VPC
                      Outputs:
                        ARN:
                          Value: !GetAtt 
                            - ControlPlane
                            - Arn
                          Export:
                            Name: !Sub '${AWS::StackName}::ARN'
                        CertificateAuthorityData:
                          Value: !GetAtt 
                            - ControlPlane
                            - CertificateAuthorityData
                        ClusterSecurityGroupId:
                          Value: !GetAtt 
                            - ControlPlane
                            - ClusterSecurityGroupId
                          Export:
                            Name: !Sub '${AWS::StackName}::ClusterSecurityGroupId'
                        ClusterStackName:
                          Value: !Ref 'AWS::StackName'
                        Endpoint:
                          Value: !GetAtt 
                            - ControlPlane
                            - Endpoint
                          Export:
                            Name: !Sub '${AWS::StackName}::Endpoint'
                        FeatureNATMode:
                          Value: Single
                        SecurityGroup:
                          Value: !Ref ControlPlaneSecurityGroup
                          Export:
                            Name: !Sub '${AWS::StackName}::SecurityGroup'
                        ServiceRoleARN:
                          Value: !GetAtt 
                            - ServiceRole
                            - Arn
                          Export:
                            Name: !Sub '${AWS::StackName}::ServiceRoleARN'
                        SharedNodeSecurityGroup:
                          Value: !Ref ClusterSharedNodeSecurityGroup
                          Export:
                            Name: !Sub '${AWS::StackName}::SharedNodeSecurityGroup'
                        SubnetsPrivate:
                          Value: !Join 
                            - ','
                            - - !Ref SubnetPrivateAPSOUTHEAST2C
                              - !Ref SubnetPrivateAPSOUTHEAST2A
                              - !Ref SubnetPrivateAPSOUTHEAST2B
                          Export:
                            Name: !Sub '${AWS::StackName}::SubnetsPrivate'
                        SubnetsPublic:
                          Value: !Join 
                            - ','
                            - - !Ref SubnetPublicAPSOUTHEAST2C
                              - !Ref SubnetPublicAPSOUTHEAST2A
                              - !Ref SubnetPublicAPSOUTHEAST2B
                          Export:
                            Name: !Sub '${AWS::StackName}::SubnetsPublic'
                        VPC:
                          Value: !Ref VPC
                          Export:
                            Name: !Sub '${AWS::StackName}::VPC'
                      
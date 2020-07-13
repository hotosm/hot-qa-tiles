const cf = require('@mapbox/cloudfriend');

const parameters = {
  GitSha: {
    Type: 'String',
    Description: 'GitSha for this stack'
  },
  OAuthToken: {
    Type: 'String',
    Description: 'OAuthToken with permissions to clone hot-qa-tiles'
  }
};

const resources = {
  HotQATilesASG: {
    Type: 'AWS::AutoScaling::AutoScalingGroup',
    Properties: {
      AutoScalingGroupName: cf.stackName,
      Cooldown: 300,
      MinSize: 0,
      DesiredCapacity: 1,
      MaxSize: 1,
      HealthCheckGracePeriod: 300,
      HealthCheckType: 'EC2',
      AvailabilityZones: cf.getAzs(cf.region),
      MixedInstancesPolicy: {
        LaunchTemplate: {
          LaunchTemplateSpecification: {
            LaunchTemplateId: cf.ref('HOTQATilesEC2LaunchTemplate'),
            Version: 1
          },
          Overrides: [{
            InstanceType: 'r3.8xlarge'
          },{
            InstanceType: 'r5d.4xlarge'
          }]
        },
        InstancesDistribution: {
          OnDemandAllocationStrategy: 'prioritized',
          OnDemandBaseCapacity: 0,
          OnDemandPercentageAboveBaseCapacity: 50,
          SpotAllocationStrategy: 'lowest-price',
          SpotInstancePools: 2
        }
      },
      Tags: [
        {
          Key: 'Name',
          Value: 'HOT-QA-Tiles',
          PropagateAtLaunch: true
        }, {
          Key: 'Environment',
          Value: cf.stackName,
          PropagateAtLaunch: true
        }
      ]
    }
  },
  HOTQATilesASGScheduledAction: {
    Type: 'AWS::AutoScaling::ScheduledAction',
    Properties: {
      AutoScalingGroupName: cf.ref('HotQATilesASG'),
      DesiredCapacity: 1,
      MaxSize: 1,
      MinSize: 0,
      Recurrence: '15 7 * * 1'
    }
  },
  HOTQATilesEC2LaunchTemplate: {
    Type: 'AWS::EC2::LaunchTemplate',
    Properties: {
      LaunchTemplateName: cf.join('-', [cf.stackName, 'ec2', 'launch', 'template']),
      LaunchTemplateData: {
        UserData: cf.userData([
          '#!/bin/bash',
          'while [ ! -e /dev/xvdc ]; do echo waiting for /dev/xvdc to attach; sleep 10; done',
          'while [ ! -e /dev/xvdb ]; do echo waiting for /dev/xvdb to attach; sleep 10; done',
          'sudo mkdir -p hot-qa-tiles-generator',
          'sudo mkfs -t ext3 /dev/xvdc',
          'sudo mount /dev/xvdc hot-qa-tiles-generator/',
          'sudo mkfs -t ext3 /dev/xvdb',
          'sudo mount /dev/xvdb /tmp',
          'sudo yum install -y lvm2 wget vim tmux htop traceroute git gcc gcc-c++ make openssl-devel kernel-devel, mesa-libGL mesa-libGL-devel xorg-x11-server-Xorg.x86_64 libpcap pigz',
          'sudo yum --enablerepo epel install -y moreutils',
          'curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash',
          'export NVM_DIR="$HOME/.nvm"',
          '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"',
          '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"',
          'nvm install v9',
          'npm install mbtiles-extracts -g --unsafe',
          'git clone https://github.com/mapbox/mason.git ~/.mason',
          'sudo ln -s ~/.mason/mason /usr/local/bin/mason',
          '~/.mason/mason install libosmium 2.13.1',
          '~/.mason/mason link libosmium 2.13.1',
          '~/.mason/mason install minjur a2c9dc871369432c7978718834dac487c0591bd6',
          '~/.mason/mason link minjur a2c9dc871369432c7978718834dac487c0591bd6',
          '~/.mason/mason install tippecanoe 1.31.0',
          '~/.mason/mason link tippecanoe 1.31.0',
          'echo $PATH',
          'export PATH=$PATH:/mason_packages/.link/bin/',
          'sudo chmod 777 hot-qa-tiles-generator/',
          'cd hot-qa-tiles-generator/',
          cf.sub('git clone https://${OAuthToken}@github.com/hotosm/hot-qa-tiles.git && cd hot-qa-tiles && git checkout ${GitSha}'),
          cf.sub('screen -dLmS "tippecanoe" bash -c "sudo chmod 777 mbtiles-updated.sh;HotQATilesASG=${AWS::StackName} region=${AWS::Region} ./mbtiles-updated.sh"')
        ]),
        InstanceInitiatedShutdownBehavior: 'terminate',
        IamInstanceProfile: {
          Name: cf.ref('HOTQATilesEC2InstanceProfile')
        },
        KeyName: 'mbtiles',
        ImageId: 'ami-0aff68d244cd33eb4'
      }
    }
  },
  HOTQATilesEC2Role: {
    Type: 'AWS::IAM::Role',
    Properties: {
      AssumeRolePolicyDocument: {
        Version: "2012-10-17",
        Statement: [{
          Effect: "Allow",
          Principal: {
             Service: [ "ec2.amazonaws.com" ]
          },
          Action: [ "sts:AssumeRole" ]
        }]
      },
      Policies: [{
        PolicyName: "S3Policy",
        PolicyDocument: {
          Version: "2012-10-17",
          Statement:[{
            Action: [ 's3:ListBucket'],
            Effect: 'Allow',
            Resource: ['arn:aws:s3:::hot-qa-tiles']
          }, {
            Action: [
                's3:GetObject',
                's3:GetObjectAcl',
                's3:PutObject',
                's3:PutObjectAcl',
                's3:ListObjects',
                's3:DeleteObject'
            ],
            Effect: 'Allow',
            Resource: [
                'arn:aws:s3:::hot-qa-tiles/*'
            ]
          }, {
            Action: [
                'autoscaling:UpdateAutoScalingGroup'
            ],
            Effect: 'Allow',
            Resource: [ cf.join('',['arn:aws:autoscaling:',cf.region,':', cf.accountId, ':autoScalingGroup:*:autoScalingGroupName/', cf.stackName]) ]
          }]
        }
      }],
      RoleName: cf.join('-', [cf.stackName, 'ec2', 'role'])
    }
  },
  HOTQATilesEC2InstanceProfile: {
     Type: "AWS::IAM::InstanceProfile",
     Properties: {
        Roles: [cf.ref('HOTQATilesEC2Role')],
        InstanceProfileName: cf.join('-', [cf.stackName, 'ec2', 'instance', 'profile'])
     }
  },

};

module.exports = cf.merge({ Parameters: parameters, Resources: resources });

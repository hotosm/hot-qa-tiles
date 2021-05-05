// Copyright (C) 2021 Humanitarian OpenStreetmap Team

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Humanitarian OpenStreetmap Team
// 1100 13th Street NW Suite 800 Washington, D.C. 20005
// <info@hotosm.org>

const cf = require('@mapbox/cloudfriend');

const parameters = {
  GitSha: {
    Type: 'String',
    Description: 'GitSha for this stack'
  },
  OAuthToken: {
    Type: 'String',
    Description: 'OAuthToken with permissions to clone hot-qa-tiles'
  },
  s3DestinationPath: {
    Type: 'String',
    Description: 's3 path for where files will be uploaded'
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
            InstanceType: 'r5d.8xlarge'
          },{
            InstanceType: 'r5dn.8xlarge'
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
      Recurrence: '15 7 * * 2'
    }
  },
  HOTQATilesEC2LaunchTemplate: {
    Type: 'AWS::EC2::LaunchTemplate',
    Properties: {
      LaunchTemplateName: cf.join('-', [cf.stackName, 'ec2', 'launch', 'template']),
      LaunchTemplateData: {
        UserData: cf.userData([
          '#!/bin/bash',
          'while [ ! -e /dev/nvme1n1 ]; do echo waiting for /dev/nvme1n1 to attach; sleep 10; done',
          'while [ ! -e /dev/nvme2n1 ]; do echo waiting for /dev/nvme2n1 to attach; sleep 10; done',
          'sudo mkdir -p hot-qa-tiles-generator',
          'sudo mkfs -t ext3 /dev/nvme1n1',
          'sudo mount /dev/nvme1n1 hot-qa-tiles-generator/',
          'sudo mkfs -t ext3 /dev/nvme2n1',
          'sudo mount /dev/nvme2n1 /tmp',
          'sudo yum install -y lvm2 wget vim tmux htop traceroute git gcc gcc-c++ make openssl-devel kernel-devel, mesa-libGL mesa-libGL-devel xorg-x11-server-Xorg.x86_64 libpcap pigz',
          'sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm',
          'sudo yum-config-manager --enable epel',
          'sudo yum install -y moreutils',
          'curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash',
          'export NVM_DIR="$HOME/.nvm"',
          '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"',
          '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"',
          'nvm install v9',
          'npm install mbtiles-extracts -g --unsafe',
          'npm install json-stream-reduce',
          'npm install @turf/area',
          'git clone --depth=1 https://github.com/mapbox/mason.git ~/.mason',
          'sudo ln -s ~/.mason/mason /usr/local/bin/mason',
          '~/.mason/mason install osmium-tool 1.11.0',
          '~/.mason/mason link  osmium-tool 1.11.0',
          '~/.mason/mason install tippecanoe 1.32.10',
          '~/.mason/mason link tippecanoe 1.32.10',
          'echo $PATH',
          'export PATH=$PATH:/mason_packages/.link/bin/',
          'export LC_ALL=en_US.UTF-8',
          'sudo chmod 777 /hot-qa-tiles-generator/',
          'cd /hot-qa-tiles-generator/',
          cf.sub('git clone https://${OAuthToken}@github.com/hotosm/hot-qa-tiles.git && cd hot-qa-tiles && git checkout ${GitSha}'),
          cf.sub('screen -dLmS "tippecanoe" bash -c "sudo chmod 777 mbtiles-updated.sh;HotQATilesASG=${AWS::StackName} region=${AWS::Region} ./mbtiles-updated.sh ${s3DestinationPath}"')
        ]),
        InstanceInitiatedShutdownBehavior: 'terminate',
        IamInstanceProfile: {
          Name: cf.ref('HOTQATilesEC2InstanceProfile')
        },
        KeyName: 'mbtiles',
        ImageId: 'ami-08f3d892de259504d',

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
            Resource: ['arn:aws:s3:::hot-qa-tiles', 'arn:aws:s3:::hot-qa-tiles-test']
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
                'arn:aws:s3:::hot-qa-tiles/*',
                'arn:aws:s3:::hot-qa-tiles-test/*'
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

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
          }, {
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
      }
    }
  },
  HOTQATilesASGScheduledAction: {
    Type: 'AWS::AutoScaling::ScheduledAction',
    Properties: {
      AutoScalingGroupName: cf.ref('HotQATilesASG'),
      DesiredCapacity: 1,
      MaxSize: 1,
      MinSize: 0,
      Recurrence: '15 7 * * *'
    }
  },
  HOTQATilesEC2LaunchTemplate: {
    Type: 'AWS::EC2::LaunchTemplate',
    Properties: {
      LaunchTemplateName: cf.join('-', [cf.stackName, 'ec2', 'launch', 'template']),
      LaunchTemplateData: {
        UserData: cf.userData(["#!/bin/bash",
            cf.sub('export STACK_NAME=${AWS::StackName}'),
            cf.sub('export REGION=${AWS::Region}'),
            cf.sub('export GITSHA=${GitSha}'),
            cf.sub('export OAUTH=${OAuthToken}'),
            'sudo yum install -y git',
            'git clone https://${OAUTH}@github.com/hotosm/hot-qa-tiles.git && cd hot-qa-tiles && git checkout ${GITSHA}',
            'ls -l',
            'chmod 775 ./cloudformation/mount-drive.sh',
            './cloudformation/mount-drive.sh',
            'sudo chmod 777 hot-qa-tiles-generator/',
            'mv hot-qa-tiles hot-qa-tiles-generator/',
            'cd hot-qa-tiles-generator/',
            'git clone https://${OAUTH}@github.com/hotosm/hot-qa-tiles.git && cd hot-qa-tiles && git checkout ${GITSHA}',
            'ls -l',
            'chmod 775 ./hot-qa-tiles/cloudformation/dependencies.sh',
            'chmod 775 ./hot-qa-tiles/cloudformation/run-process.sh',
            './hot-qa-tiles/cloudformation/dependencies.sh',
            './hot-qa-tiles/cloudformation/run-process.sh']),
        InstanceInitiatedShutdownBehavior: 'terminate',
        IamInstanceProfile: {
          Name: cf.ref('HOTQATilesEC2InstanceProfile')
        },
        KeyName: 'mbtiles',
        ImageId: 'ami-f6ed648c'
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

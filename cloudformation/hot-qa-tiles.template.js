const cf = require('@mapbox/cloudfriend');

const parameters = {
    GitSha: {
        Description: 'hot-qa-tiles GitSha',
        Type: 'String'
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
        AvailabilityZone: cf.getAzs(cf.region),
        MixedInstancesPolicy: {
          LaunchTemplate: {
            LaunchTemplateSpecification: {
              LaunchTemplateName: cf.ref('HOTQATilesEC2LaunchTemplate'),
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
      Recurrence: '30 10 * * ? *'
    }
  },
  HOTQATilesEC2LaunchTemplate: {
    Type: 'AWS::EC2::LaunchTemplate',
    Properties: {
      LaunchTemplateName: cf.join('-', [cf.stackName, 'ec2', 'launch', 'template']),
      LaunchTemplateData: {
        UserData: 'TODO',
        InstanceInitiatedShutdownBehavior: 'terminate',
        IamInstanceProfile: cf.ref('HOTQATilesEC2InstanceProfile'),
        KeyName: 'mbtiles',
        ImageId: 'ami-dd4496a5'
      }
    }
  },
  HOTQATilesEC2Role: {
    Type: 'AWS::IAM::Role',
    Properties: {
      AssumeRolePolicyDocument: {
        Version: "2012-10-17",
        Statement: [ {
          Effect: "Allow",
          Principal: {
             Service: [ "ec2.amazonaws.com" ]
          },
          Action: [ "sts:AssumeRole" ]
        } ]
      },
      Policies: [ {
        PolicyName: "S3Policy",
        PolicyDocument: {
          Version: "2012-10-17",
          Statement:[
          {
              Action: [ 's3:ListBucket'],
              Effect: 'Allow',
              Resource: ['arn:aws:s3:::hot-qa-tiles']
          },
          {
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
          }
      ],
      RoleName: cf.join('-', [cf.stackName, 'ec2', 'role'])
    }
  },
  HOTQATilesEC2InstanceProfile: {
     Type: "AWS::IAM::InstanceProfile",
     Properties: {
        Roles: cf.ref('HOTQATilesEC2Role'),
        InstanceProfileName: cf.join('-', [cf.stackName, 'ec2', 'instance', 'profile'])
     }
  },

};

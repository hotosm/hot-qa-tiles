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
              LaunchTemplateName: cf.stackName,
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
  }
}
const qaTilesS3Permissions = [
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
];

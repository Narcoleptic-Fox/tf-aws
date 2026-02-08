# ECS Cluster Module

Container orchestration with Fargate and EC2 capacity.

## Features

- [ ] Fargate capacity provider
- [ ] EC2 capacity provider (optional)
- [ ] Container Insights enabled
- [ ] Service discovery namespace
- [ ] Cluster auto-scaling
- [ ] Task definition templates

## Usage (Coming Soon)

```hcl
module "ecs" {
  source = "./modules/tf-aws/compute/ecs-cluster"
  
  name                 = module.naming.prefix
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  enable_fargate       = true
  enable_container_insights = true
  
  tags = module.tags.common_tags
}
```

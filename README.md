# The Illusion of 100% Uptime

**45 minutes | Easy-Medium | GCP | ~$1**

> Note: This lab has some production features (IAM, monitoring, Cloud Armor) but still uses HTTP instead of HTTPS. It's good for learning, better than a basic demo, but not fully production-ready.

## What's this about?

Ever notice how Gmail or YouTube never seem to go down? It's not magic. Their servers fail all the time - you just don't see it.

The trick is simple: run multiple copies of everything. When one fails, traffic goes to the others. This workshop shows you how it works.

You'll deploy a simple web app to GCP, then deliberately break things and watch the system keep running anyway.

**What you need:**
- GCP account (costs less than $1)
- gcloud CLI and Terraform installed  
- Know how web apps work (basic level)

## How it works

We'll run 3 copies of the same app in different datacenters (zones). A load balancer sends traffic to all of them. If one dies, the others keep working.

Health checks run every 5 seconds. Two failed checks and that instance is marked bad. The load balancer stops sending it traffic. After 60 seconds, the system creates a new instance to replace it.

The math: 
- One server: 99.9% uptime (down ~9 hours per year)
- Three servers in different zones: 99.999% uptime (down ~5 minutes per year)

The difference is huge.

## Setup

### Step 1: Enable APIs (5 min)

```bash
cd gcp-illusion-of-uptime
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID
gcloud services enable compute.googleapis.com cloudresourcemanager.googleapis.com monitoring.googleapis.com
```

Wait about 30 seconds.

### Step 2: Deploy everything (10 min)

```bash
cd terraform
terraform init
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars - put your project_id in there
terraform apply
```

This creates 3 VM instances, a load balancer, health checks, monitoring, and all the networking. Takes 2-3 minutes after terraform finishes for everything to boot up.

### Step 3: Test it (5 min)

```bash
LOAD_BALANCER_IP=$(terraform output -raw load_balancer_ip)
curl http://$LOAD_BALANCER_IP
```

You should see a webpage. Run the monitor script to watch which instance responds:

```bash
../scripts/monitor-instances.sh $LOAD_BALANCER_IP
```

Each request might hit a different instance. That's the load balancer doing its job.

### Step 4: Break something (10 min)

Now for the interesting part. Let's kill one instance and see what happens.

```bash
# See your instances
gcloud compute instance-groups managed list-instances uptime-mig --region=us-central1

# SSH into one
gcloud compute ssh INSTANCE_NAME --zone=ZONE

# Kill the app
sudo systemctl stop uptime-app
exit
```

Watch the health checks:
```bash
watch -n 5 'gcloud compute backend-services get-health uptime-backend-service --global'
```

Within 10 seconds, that instance is marked unhealthy. Load balancer stops sending it traffic. After 60 seconds, a new instance gets created automatically.

Meanwhile, your app kept working the whole time because the other two instances were still running.

### Step 5: Kill an entire zone (10 min)

What if a whole datacenter goes offline?

```bash
../scripts/simulate-zone-failure.sh us-central1-a
../scripts/monitor-instances.sh $LOAD_BALANCER_IP
```

The app still works. You're running at 66% capacity now, but users can still access it. The two remaining zones handle everything.

### Step 6: The numbers (5 min)

Here's what happened:
- Detection time: 10 seconds
- Failover: instant (load balancer just stops routing there)
- Recovery: 60 seconds for the new instance
- User impact: zero

One VM gives you 99.9% uptime - roughly 9 hours of downtime per year. Three VMs spread across zones? 99.999% - about 5 minutes per year.

That's the whole trick. Things break constantly but users never notice.

## Problems?

**APIs won't enable:** Make sure billing is enabled on your project.

**502 errors:** Wait 2-3 minutes after deployment. Instances need time to boot.

**Can't SSH:** Run `gcloud compute config-ssh` first.

**App won't start:** The Python app runs on port 8080, nginx forwards from port 80. Check both:
```bash
sudo systemctl status nginx
sudo systemctl status uptime-app
```

**Check health:**
```bash
gcloud compute backend-services get-health uptime-backend-service --global
```

## Cleanup

Don't forget this or you'll get a bill.

```bash
cd terraform
terraform destroy
```

Double check everything is gone:
```bash
gcloud compute instances list
gcloud compute forwarding-rules list
```

Cost is about $0.09/hour. If you forget to destroy, it costs ~$68/month.

## What you learned

1. Multiple copies across different zones = your app stays up
2. Health checks find problems fast
3. Auto-healing fixes problems automatically
4. Real systems fail all the time, but users don't see it

## What's in this lab

This lab includes some good production practices:
- App runs as a regular user (not root)
- Nginx handles the web traffic (better than having Python do it directly)
- IAM service account with limited permissions
- Cloud Armor for DDoS protection
- Monitoring and alerts
- Proper logging

## What's missing

For a real production app, you'd still need:
- HTTPS (this uses HTTP only - would need a domain and certificates)
- Custom VPC with private subnets
- Authentication (add OAuth or IAP)
- Database (this app doesn't save anything)
- CI/CD pipeline
- Auto-scaling (this uses fixed 3 instances)
- Multi-region setup

So this is better than a basic demo but not fully production-ready. Good enough to learn from though.

## More reading

- [GCP High Availability docs](https://cloud.google.com/architecture/scalable-and-resilient-apps)
- [Google SRE Book](https://sre.google/sre-book/embracing-risk/)

**License:** MIT

- [Google SRE Book](https://sre.google/sre-book/embracing-risk/)
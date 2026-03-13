# The Illusion of 100% Uptime

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

### Step 1: Clone the repo

```bash
git clone https://github.com/misskecupbung/gcp-illusion-of-uptime.git
cd gcp-illusion-of-uptime
```

### Step 2: Enable APIs

```bash
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID
gcloud services enable compute.googleapis.com cloudresourcemanager.googleapis.com monitoring.googleapis.com
```

Wait about 30 seconds.

### Step 3: Deploy everything

```bash
cd terraform
terraform init
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars - put your project_id in there
terraform apply
```

This creates 3 VM instances, a load balancer, health checks, monitoring, and all the networking. Takes 2-3 minutes after terraform finishes for everything to boot up.

### Step 4: Test it

```bash
LOAD_BALANCER_IP=$(terraform output -raw load_balancer_ip)
curl http://$LOAD_BALANCER_IP
```

You should see a webpage. Run the monitor script to watch which instance responds:

```bash
../scripts/monitor-instances.sh $LOAD_BALANCER_IP
```

Each request might hit a different instance. That's the load balancer doing its job.

### Step 5: Break something

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

### Step 6: Kill an entire zone

What if a whole datacenter goes offline?

```bash
../scripts/simulate-zone-failure.sh us-central1-a
../scripts/monitor-instances.sh $LOAD_BALANCER_IP
```

The app still works. You're running at 66% capacity now, but users can still access it. The two remaining zones handle everything.

### Step 7: The numbers

Here's what happened:
- Detection time: 10 seconds
- Failover: instant (load balancer just stops routing there)
- Recovery: 60 seconds for the new instance
- User impact: zero

One VM gives you 99.9% uptime - roughly 9 hours of downtime per year. Three VMs spread across zones? 99.999% - about 5 minutes per year.

That's the whole trick. Things break constantly but users never notice.

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

## Resources

- [GCP High Availability docs](https://cloud.google.com/architecture/scalable-and-resilient-apps)
- [Google SRE Book](https://sre.google/sre-book/embracing-risk/)

**License:** MIT
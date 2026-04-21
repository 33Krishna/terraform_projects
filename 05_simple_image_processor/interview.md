# Interview Questions & Answers – Simple Image Processor Project

## 1. Explain your project in 1 minute.

**Answer:** I built a serverless image processing pipeline on AWS using Terraform. When a user uploads an image to an S3 source bucket, an S3 event triggers an AWS Lambda function. The Lambda function processes the image into multiple optimized variants such as compressed JPEG, WebP, PNG, and thumbnail versions, then stores them in a processed S3 bucket. I used Terraform to provision all infrastructure and CloudWatch for logs and monitoring.

---

## 2. Why did you use two S3 buckets?

**Answer:** I used one bucket for original uploads and another bucket for processed outputs. This keeps source files separate from generated files, improves organization, simplifies permissions, and avoids accidental overwrite loops.

---

## 3. Why did you choose Lambda instead of EC2?

**Answer:** Lambda was suitable because image processing happens only when files are uploaded. It is event-driven, scales automatically, and I only pay when it runs. Using EC2 would require always-on servers and more maintenance.

---

## 4. Why Terraform?

**Answer:** Terraform allowed me to manage infrastructure as code. I could create S3 buckets, IAM roles, Lambda, and triggers in a repeatable way instead of manual console steps.

---

## 5. What happens when a user uploads an image?

**Answer:** The image is uploaded to the source bucket. S3 sends an ObjectCreated event to Lambda. Lambda downloads the file, processes variants, uploads outputs to the processed bucket, and writes logs to CloudWatch.

---

## Troubleshooting Questions

## 6. Lambda is not triggering after upload. What would you check?

**Answer:** I would check:

1. S3 event notification configuration
2. Lambda invoke permission for S3
3. Correct bucket and region
4. CloudWatch logs for errors
5. Whether file was uploaded successfully

---

## 7. Lambda fails with `No module named PIL`.

**Answer:** That means the Pillow dependency is missing or the Lambda Layer is not attached correctly. I would rebuild the layer, verify runtime compatibility, and reattach the layer.

---

## 8. Terraform apply fails because bucket already exists.

**Answer:** S3 bucket names are globally unique. I used a random suffix in Terraform to avoid naming conflicts.

---

## 9. Terraform destroy fails for S3 bucket.

**Answer:** Usually buckets still contain objects or versioned files. I would empty the bucket, including versions and delete markers, then run destroy again.

---

## 10. Uploaded image is corrupted or unsupported.

**Answer:** I would add validation in Lambda to verify file type and reject invalid files gracefully with logs.

---

## Real Scenario Questions

## 11. What if 10,000 users upload images at the same time?

**Answer:** Lambda can scale automatically, but I would also monitor concurrency limits. For better resilience, I would add SQS between S3 and Lambda to buffer traffic spikes.

---

## 12. What if image processing fails temporarily?

**Answer:** I would configure retry handling and a Dead Letter Queue so failed events are stored for later reprocessing.

---

## 13. How would you reduce cost?

**Answer:** I would optimize Lambda memory/time, delete old processed files using S3 lifecycle rules, and use efficient formats like WebP to reduce bandwidth.

---

## 14. How would you secure the system?

**Answer:** I would keep buckets private, enable encryption, use IAM least privilege, block public access, and use logging for auditing.

---

## 15. How would users upload from website frontend?

**Answer:** I would use a backend API to generate pre-signed S3 URLs so users can upload directly to S3 securely.

---

## Improvement Questions

## 16. What would you improve next?

**Answer:** I would add CI/CD with GitHub Actions, SQS + DLQ, CloudWatch alarms, remote Terraform backend, and CloudFront for image delivery.

---

## 17. Why did you use a Lambda Layer?

**Answer:** Lambda runtime does not include Pillow by default. I used a Lambda Layer to package dependencies separately and keep deployments cleaner.

---

## 18. Why Docker in your project?

**Answer:** I used Docker to build the Pillow layer in a Linux environment compatible with AWS Lambda.

---

## HR / Ownership Questions

## 19. What was the biggest challenge?

**Answer:** Packaging Python dependencies for Lambda compatibility was a challenge. I solved it by building the layer with Docker.

---

## 20. What did you learn from this project?

**Answer:** I learned event-driven architecture, Terraform automation, IAM permissions, serverless workflows, debugging cloud services, and dependency packaging.

---

## Quick Tips for Interview

* Speak in flow: Upload -> Trigger -> Process -> Store -> Monitor
* Mention business value: faster images, automation, lower ops effort
* Mention improvements: SQS, DLQ, CI/CD
* If unsure, explain how you would troubleshoot logically

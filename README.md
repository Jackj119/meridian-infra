# meridian-infra: 
This repository utilizes OpenTofu configuration for Meridian Labs that uses a VPC, EC2 instance, and an S3 bucket. It runs against LocalStack and imitates AWS locally. The configuration has input variables, outputs, and a state backend declaration. 

# Experienced Errors & Solutions: 
1. “Error: The security token included in the request is invalid.” I received this error when I was demonstrating drift by attempting an HTTP request in the PowerShell terminal. Since LocalStack is local and I was making requests with HTTPS, it was only a typo that was an easy fix after reviewing my prior commands. 

2. The second error occurred because my job was trying to validate my decoy credentials against real AWS. After consulting Claude, it said it updated with this in mind, and I pushed it again to GitHub from the terminal. 

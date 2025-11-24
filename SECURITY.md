# 🛡️ SECURITY GUIDELINES - AWS Deployment

## ⚠️ IMPORTANT SECURITY NOTICE

This repository contains deployment configurations for AWS EKS. Follow these guidelines to maintain security best practices.

## 🔐 AWS Credentials Management

### ❌ NEVER DO:
- Commit AWS credentials to git
- Use hardcoded secrets in code
- Share credentials in plain text
- Use production credentials for development

### ✅ SECURE PRACTICES:

#### 1. Use Environment Variables (Recommended)
```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_SESSION_TOKEN="your_session_token"  # For sandbox/temporary credentials
export AWS_DEFAULT_REGION="us-east-1"
```

#### 2. Use AWS Credentials File (Local development only)
```bash
# Create credentials file from template
cp aws-credentials-template.txt aws-credentials.txt
# Edit with your credentials (this file is in .gitignore)
```

#### 3. Use IAM Roles (Production)
- Attach IAM roles to EC2 instances
- Use AWS IAM Identity Center (SSO)
- Use temporary credentials through AWS STS

## 🏗️ Deployment Security

### For Sandbox/Development:
1. Use temporary credentials with limited permissions
2. Set short expiration times
3. Use separate AWS accounts for dev/prod

### For Production:
1. Use IAM roles with minimal required permissions
2. Enable AWS CloudTrail for audit logging
3. Use AWS Secrets Manager for application secrets
4. Enable encryption at rest and in transit

## 📋 Security Checklist

Before deploying:
- [ ] Credentials are not in git history
- [ ] Using temporary/sandbox credentials
- [ ] IAM permissions follow least privilege
- [ ] All secrets are encrypted
- [ ] Monitoring and logging enabled
- [ ] Network security groups configured
- [ ] SSL/TLS certificates in place

## 🚨 If Credentials Are Compromised

1. **Immediate Actions:**
   ```bash
   # Revoke credentials immediately in AWS Console
   # Change all affected passwords
   # Rotate all API keys
   ```

2. **Git History Cleanup:**
   ```bash
   # Remove from git history
   git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch aws-credentials.txt' --prune-empty --tag-name-filter cat -- --all
   git push origin --force --all
   ```

3. **Notify team and update security policies**

## 📞 Emergency Contacts

- AWS Support: https://support.aws.amazon.com/
- Security Incident: Report immediately to admin
- Git History Issues: Contact DevOps team

## 🔗 Additional Resources

- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)

---
**Remember: Security is everyone's responsibility! 🛡️**
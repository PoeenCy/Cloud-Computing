# GitHub Secrets Setup Guide

## 📋 Required GitHub Secrets

Để workflow CI/CD có thể chạy được, bạn cần tạo các GitHub Secrets sau trong repository:

### 🔐 AWS Credentials

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID cho IAM user có quyền ECR | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_ACCOUNT_ID` | AWS Account ID (12 digits) | `123456789012` |

**IAM Permissions Required:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
```

### 🖥️ SSH Configuration

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `SSH_USERNAME` | SSH username cho cả 2 servers | `ec2-user` hoặc `ubuntu` |
| `SSH_PRIVATE_KEY` | SSH private key (RSA/ED25519) | `-----BEGIN RSA PRIVATE KEY-----\n...` |
| `SSH_PORT` | SSH port (thường là 22) | `22` |

**Lưu ý về SSH_PRIVATE_KEY:**
- Copy toàn bộ nội dung file private key (bao gồm cả header và footer)
- Giữ nguyên format với line breaks
- Ví dụ:
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
...
-----END RSA PRIVATE KEY-----
```

### 🌐 Server Hostnames/IPs

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `APP1_HOST` | IP hoặc hostname của App Server 1 | `10.0.1.10` hoặc `app1.example.com` |
| `APP2_HOST` | IP hoặc hostname của App Server 2 | `10.0.1.20` hoặc `app2.example.com` |

---

## 🛠️ Cách tạo GitHub Secrets

### Bước 1: Truy cập Settings
1. Vào repository trên GitHub
2. Click tab **Settings**
3. Trong sidebar bên trái, click **Secrets and variables** → **Actions**

### Bước 2: Thêm Secret
1. Click nút **New repository secret**
2. Nhập **Name** (tên secret từ bảng trên)
3. Nhập **Value** (giá trị tương ứng)
4. Click **Add secret**

### Bước 3: Lặp lại
Lặp lại Bước 2 cho tất cả 8 secrets trong danh sách.

---

## ✅ Checklist

Sau khi tạo xong, hãy kiểm tra lại:

- [ ] `AWS_ACCESS_KEY_ID` - AWS Access Key
- [ ] `AWS_SECRET_ACCESS_KEY` - AWS Secret Key
- [ ] `AWS_ACCOUNT_ID` - AWS Account ID (12 digits)
- [ ] `SSH_USERNAME` - SSH username
- [ ] `SSH_PRIVATE_KEY` - SSH private key (full content)
- [ ] `SSH_PORT` - SSH port (thường là 22)
- [ ] `APP1_HOST` - App Server 1 IP/hostname
- [ ] `APP2_HOST` - App Server 2 IP/hostname

---

## 🔧 Chuẩn bị EC2 Servers

### Yêu cầu trên mỗi EC2 instance:

1. **Docker đã được cài đặt:**
```bash
# Install Docker
sudo yum update -y
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

2. **AWS CLI đã được cài đặt:**
```bash
# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

3. **AWS Credentials được cấu hình:**
```bash
aws configure
# Nhập AWS Access Key ID
# Nhập AWS Secret Access Key
# Nhập region: ap-southeast-1
```

4. **Docker networks đã được tạo:**
```bash
docker network create minicloud_frontend-net
docker network create minicloud_backend-net
docker network create minicloud_mgmt-net
```

5. **SSH access được cấu hình:**
- Public key đã được thêm vào `~/.ssh/authorized_keys`
- Security Group cho phép SSH từ GitHub Actions IPs

---

## 🧪 Test Workflow

Sau khi setup xong, test workflow bằng cách:

1. **Push code lên main branch:**
```bash
git add .
git commit -m "test: trigger CI/CD pipeline"
git push origin main
```

2. **Hoặc trigger thủ công:**
- Vào tab **Actions** trên GitHub
- Chọn workflow **CI/CD Pipeline - Flask App to AWS EC2**
- Click **Run workflow**

3. **Theo dõi logs:**
- Click vào workflow run
- Xem logs của từng job
- Kiểm tra status: ✅ Success hoặc ❌ Failed

---

## 🐛 Troubleshooting

### Lỗi AWS Authentication
```
Error: Unable to locate credentials
```
**Giải pháp:** Kiểm tra lại `AWS_ACCESS_KEY_ID` và `AWS_SECRET_ACCESS_KEY`

### Lỗi SSH Connection
```
Error: ssh: connect to host X.X.X.X port 22: Connection refused
```
**Giải pháp:** 
- Kiểm tra Security Group cho phép SSH
- Kiểm tra `SSH_PRIVATE_KEY` đúng format
- Kiểm tra `APP1_HOST` và `APP2_HOST` đúng IP

### Lỗi ECR Login
```
Error: Cannot perform an interactive login from a non TTY device
```
**Giải pháp:** Kiểm tra IAM permissions cho ECR

### Lỗi Health Check Failed
```
❌ Health check failed after 5 attempts
```
**Giải pháp:**
- Kiểm tra container logs: `docker logs flask_app`
- Kiểm tra port 8081 đã được expose
- Kiểm tra endpoint `/api/hello` có tồn tại

---

## 📚 Tài liệu tham khảo

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [appleboy/ssh-action](https://github.com/appleboy/ssh-action)
- [Docker Documentation](https://docs.docker.com/)

---

## 🔒 Security Best Practices

1. **Không commit secrets vào code**
2. **Rotate AWS credentials định kỳ**
3. **Sử dụng IAM roles với least privilege**
4. **Enable MFA cho AWS account**
5. **Sử dụng SSH key pairs thay vì password**
6. **Restrict Security Groups chỉ cho phép IPs cần thiết**
7. **Enable CloudTrail để audit AWS API calls**
8. **Scan Docker images cho vulnerabilities (Trivy)**

---

**Last Updated:** April 15, 2026  
**Maintainer:** DevOps Team

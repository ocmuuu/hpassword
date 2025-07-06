# hPassword 模板使用说明

## 📖 目录

1. [模板概述](#模板概述)
2. [常用模板](#常用模板)
3. [金融模板](#金融模板)
4. [通讯模板](#通讯模板)
5. [个人信息模板](#个人信息模板)
6. [技术模板](#技术模板)
7. [其他模板](#其他模板)
8. [自定义模板](#自定义模板)

## 🎯 模板概述

hPassword 提供了25种预设模板，涵盖了日常生活和工作中常见的密码管理场景。每个模板都包含特定的字段类型，自动识别敏感信息并提供相应的保护机制。

### 模板特性

- **智能字段识别**：自动识别敏感字段并加密保护
- **类型验证**：根据字段类型进行输入验证
- **个性化定制**：支持添加自定义字段
- **安全分级**：不同敏感级别的字段采用不同保护措施

## 🔐 常用模板

### 1. 登录信息 (Login)

**适用场景**：网站登录、应用账户、在线服务

**字段清单**：
```
标题 (Title) - 必填
用户名 (UserName) - 必填
密码 (Password) - 必填，受保护
网址 (URL) - 可选
备注 (Notes) - 可选
```

**使用示例**：
- 网站登录账户
- 社交媒体账户
- 在线购物账户
- 论坛社区账户

### 2. 安全备注 (SecureNote)

**适用场景**：敏感信息记录、重要文档、私密备注

**字段清单**：
```
标题 (Title) - 必填
内容 (Content) - 必填，受保护
类型 (Type) - 可选
备注 (Notes) - 可选
```

**使用示例**：
- 重要文档记录
- 私密信息备忘
- 安全问题答案
- 紧急联系信息

## 💳 金融模板

### 3. 银行账户 (BankAccount)

**适用场景**：银行卡信息、储蓄账户、信用卡

**字段清单**：
```
标题 (Title) - 必填
银行名称 (BankName) - 必填
账户号码 (AccountNumber) - 必填，受保护
账户类型 (AccountType) - 可选
开户行 (Branch) - 可选
Swift代码 (SwiftCode) - 可选
持卡人姓名 (CardholderName) - 可选
有效期 (ExpiryDate) - 可选
CVV (CVV) - 可选，受保护
PIN码 (PIN) - 可选，受保护
备注 (Notes) - 可选
```

**使用示例**：
- 储蓄账户信息
- 信用卡信息
- 借记卡信息
- 对公账户信息

### 4. 支付账户 (PaymentAccount)

**适用场景**：第三方支付、电子钱包、在线支付

**字段清单**：
```
标题 (Title) - 必填
平台名称 (Platform) - 必填
账户名 (AccountName) - 必填
登录密码 (LoginPassword) - 必填，受保护
支付密码 (PayPassword) - 可选，受保护
身份验证 (Identity) - 可选，受保护
手机号 (Phone) - 可选
邮箱 (Email) - 可选
备注 (Notes) - 可选
```

**使用示例**：
- 支付宝账户
- 微信支付
- PayPal账户
- Apple Pay

### 5. 证券基金 (SecuritiesFund)

**适用场景**：证券账户、基金投资、股票交易

**字段清单**：
```
标题 (Title) - 必填
券商名称 (Broker) - 必填
账户号码 (AccountNumber) - 必填，受保护
登录密码 (LoginPassword) - 必填，受保护
交易密码 (TradingPassword) - 可选，受保护
资金密码 (FundPassword) - 可选，受保护
身份证号 (IDNumber) - 可选，受保护
银行卡号 (BankCard) - 可选，受保护
备注 (Notes) - 可选
```

**使用示例**：
- 证券交易账户
- 基金投资账户
- 期货账户
- 外汇账户

## 📧 通讯模板

### 6. 邮箱账户 (EmailAccount)

**适用场景**：电子邮件、企业邮箱、个人邮箱

**字段清单**：
```
标题 (Title) - 必填
邮箱地址 (Email) - 必填
密码 (Password) - 必填，受保护
收件服务器 (IncomingServer) - 可选
发件服务器 (OutgoingServer) - 可选
端口 (Port) - 可选
加密方式 (Encryption) - 可选
备注 (Notes) - 可选
```

**使用示例**：
- 个人邮箱
- 企业邮箱
- 学校邮箱
- 临时邮箱

### 7. 会员卡 (MembershipCard)

**适用场景**：会员积分、VIP卡、优惠卡

**字段清单**：
```
标题 (Title) - 必填
会员号 (MemberNumber) - 必填
密码 (Password) - 可选，受保护
会员等级 (Level) - 可选
有效期 (ExpiryDate) - 可选
积分 (Points) - 可选
联系电话 (Phone) - 可选
备注 (Notes) - 可选
```

**使用示例**：
- 超市会员卡
- 健身房会员
- 图书馆借书证
- 航空里程卡

### 8. 订阅服务 (Subscription)

**适用场景**：在线订阅、会员服务、软件许可

**字段清单**：
```
标题 (Title) - 必填
服务名称 (ServiceName) - 必填
账户名 (AccountName) - 必填
密码 (Password) - 必填，受保护
订阅类型 (SubscriptionType) - 可选
开始日期 (StartDate) - 可选
结束日期 (EndDate) - 可选
费用 (Cost) - 可选
自动续费 (AutoRenewal) - 可选
备注 (Notes) - 可选
```

**使用示例**：
- 视频会员
- 音乐订阅
- 新闻订阅
- 云存储服务

## 👥 个人信息模板

### 9. 通讯录 (AddressBook)

**适用场景**：联系人信息、紧急联系人、重要联系方式

**字段清单**：
```
标题 (Title) - 必填
姓名 (Name) - 必填
手机号 (Phone) - 可选
邮箱 (Email) - 可选
地址 (Address) - 可选
公司 (Company) - 可选
职位 (Position) - 可选
生日 (Birthday) - 可选
备注 (Notes) - 可选
```

### 10. 家庭信息 (Family)

**适用场景**：家庭成员信息、家庭共享账户、家庭重要信息

**字段清单**：
```
标题 (Title) - 必填
成员姓名 (MemberName) - 必填
关系 (Relationship) - 必填
身份证号 (IDNumber) - 可选，受保护
手机号 (Phone) - 可选
出生日期 (BirthDate) - 可选
紧急联系人 (EmergencyContact) - 可选
医疗信息 (MedicalInfo) - 可选，受保护
备注 (Notes) - 可选
```

### 11. 证书 (Certificate)

**适用场景**：资格证书、学历证书、技能认证

**字段清单**：
```
标题 (Title) - 必填
证书名称 (CertificateName) - 必填
证书编号 (CertificateNumber) - 必填，受保护
发证机构 (IssuingAuthority) - 必填
获得日期 (IssueDate) - 可选
有效期 (ExpiryDate) - 可选
等级 (Level) - 可选
备注 (Notes) - 可选
```

### 12. 保险单 (InsurancePolicy)

**适用场景**：保险单据、保险理赔、保险信息

**字段清单**：
```
标题 (Title) - 必填
保险公司 (InsuranceCompany) - 必填
保单号 (PolicyNumber) - 必填，受保护
保险类型 (InsuranceType) - 必填
被保险人 (Insured) - 必填
保险金额 (InsuranceAmount) - 可选
保险期间 (InsurancePeriod) - 可选
受益人 (Beneficiary) - 可选
备注 (Notes) - 可选
```

### 13. 公用事业 (UtilityAccount)

**适用场景**：水电气费、物业费、电话费

**字段清单**：
```
标题 (Title) - 必填
服务类型 (ServiceType) - 必填
账户号码 (AccountNumber) - 必填，受保护
客户编号 (CustomerNumber) - 可选
服务地址 (ServiceAddress) - 可选
联系电话 (Phone) - 可选
在线账户 (OnlineAccount) - 可选
密码 (Password) - 可选，受保护
备注 (Notes) - 可选
```

## 🏥 专业模板

### 14. 医疗记录 (MedicalRecord)

**适用场景**：医疗信息、病历记录、医院就诊

**字段清单**：
```
标题 (Title) - 必填
医院名称 (HospitalName) - 必填
就诊卡号 (PatientID) - 必填，受保护
医生姓名 (DoctorName) - 可选
科室 (Department) - 可选
病历号 (MedicalRecordNumber) - 可选，受保护
诊断结果 (Diagnosis) - 可选，受保护
处方信息 (Prescription) - 可选，受保护
过敏信息 (Allergies) - 可选，受保护
备注 (Notes) - 可选
```

### 15. 忠诚度计划 (LoyaltyProgram)

**适用场景**：积分计划、会员权益、优惠活动

**字段清单**：
```
标题 (Title) - 必填
计划名称 (ProgramName) - 必填
会员号 (MemberNumber) - 必填
密码 (Password) - 可选，受保护
当前积分 (CurrentPoints) - 可选
会员等级 (MemberLevel) - 可选
到期日期 (ExpiryDate) - 可选
特殊权益 (SpecialBenefits) - 可选
备注 (Notes) - 可选
```

### 16. 密钥证书 (KeyCertificate)

**适用场景**：数字证书、密钥管理、加密证书

**字段清单**：
```
标题 (Title) - 必填
证书类型 (CertificateType) - 必填
证书名称 (CertificateName) - 必填
序列号 (SerialNumber) - 必填，受保护
颁发机构 (IssuerCA) - 必填
有效期开始 (ValidFrom) - 可选
有效期结束 (ValidTo) - 可选
私钥密码 (PrivateKeyPassword) - 可选，受保护
指纹 (Fingerprint) - 可选，受保护
用途 (Usage) - 可选
备注 (Notes) - 可选
```

## 💻 技术模板

### 17. 服务器 (Server)

**适用场景**：服务器管理、远程访问、系统维护

**字段清单**：
```
标题 (Title) - 必填
服务器名称 (ServerName) - 必填
IP地址 (IPAddress) - 必填
端口 (Port) - 必填
用户名 (Username) - 必填
密码 (Password) - 必填，受保护
协议 (Protocol) - 可选
操作系统 (OS) - 可选
服务器类型 (ServerType) - 可选
备注 (Notes) - 可选
```

### 18. 数据库 (Database)

**适用场景**：数据库连接、数据库管理、开发环境

**字段清单**：
```
标题 (Title) - 必填
数据库名称 (DatabaseName) - 必填
主机地址 (Host) - 必填
端口 (Port) - 必填
用户名 (Username) - 必填
密码 (Password) - 必填，受保护
数据库类型 (DatabaseType) - 可选
连接字符串 (ConnectionString) - 可选，受保护
备注 (Notes) - 可选
```

### 19. 物联网设备 (IoTDevice)

**适用场景**：智能设备、家居控制、设备管理

**字段清单**：
```
标题 (Title) - 必填
设备名称 (DeviceName) - 必填
设备类型 (DeviceType) - 必填
设备ID (DeviceID) - 必填，受保护
WiFi密码 (WiFiPassword) - 可选，受保护
管理密码 (AdminPassword) - 可选，受保护
IP地址 (IPAddress) - 可选
MAC地址 (MACAddress) - 可选
固件版本 (FirmwareVersion) - 可选
备注 (Notes) - 可选
```

### 20. 车辆信息 (VehicleInfo)

**适用场景**：车辆管理、保险理赔、维修记录

**字段清单**：
```
标题 (Title) - 必填
车辆品牌 (Brand) - 必填
车型 (Model) - 必填
车牌号 (LicensePlate) - 必填，受保护
车架号 (VIN) - 必填，受保护
发动机号 (EngineNumber) - 可选，受保护
购买日期 (PurchaseDate) - 可选
保险公司 (InsuranceCompany) - 可选
保单号 (PolicyNumber) - 可选，受保护
备注 (Notes) - 可选
```

### 21. 路由器 (Router)

**适用场景**：网络设备、路由器配置、网络管理

**字段清单**：
```
标题 (Title) - 必填
路由器型号 (RouterModel) - 必填
IP地址 (IPAddress) - 必填
管理员用户名 (AdminUsername) - 必填
管理员密码 (AdminPassword) - 必填，受保护
WiFi名称 (WiFiSSID) - 可选
WiFi密码 (WiFiPassword) - 可选，受保护
WPS PIN (WPSPIN) - 可选，受保护
固件版本 (FirmwareVersion) - 可选
备注 (Notes) - 可选
```

### 22. API凭证 (ApiCredential)

**适用场景**：API密钥、开发接口、第三方服务

**字段清单**：
```
标题 (Title) - 必填
API名称 (APIName) - 必填
API密钥 (APIKey) - 必填，受保护
密钥ID (KeyID) - 可选，受保护
密钥秘密 (SecretKey) - 可选，受保护
访问令牌 (AccessToken) - 可选，受保护
刷新令牌 (RefreshToken) - 可选，受保护
API端点 (APIEndpoint) - 可选
有效期 (ExpiryDate) - 可选
备注 (Notes) - 可选
```

### 23. 软件许可 (SoftwareLicense)

**适用场景**：软件授权、许可证管理、正版软件

**字段清单**：
```
标题 (Title) - 必填
软件名称 (SoftwareName) - 必填
许可证号 (LicenseKey) - 必填，受保护
版本号 (Version) - 可选
序列号 (SerialNumber) - 可选，受保护
激活码 (ActivationCode) - 可选，受保护
购买日期 (PurchaseDate) - 可选
有效期 (ExpiryDate) - 可选
最大安装数 (MaxInstalls) - 可选
备注 (Notes) - 可选
```

### 24. 加密钱包 (CryptoWallet)

**适用场景**：数字货币、区块链钱包、加密资产

**字段清单**：
```
标题 (Title) - 必填
钱包名称 (WalletName) - 必填
钱包地址 (WalletAddress) - 必填，受保护
私钥 (PrivateKey) - 必填，受保护
助记词 (Seed) - 可选，受保护
钱包密码 (WalletPassword) - 可选，受保护
币种 (Currency) - 可选
余额 (Balance) - 可选
备注 (Notes) - 可选
```

### 25. 其他 (Other)

**适用场景**：通用模板、自定义信息、其他类型

**字段清单**：
```
标题 (Title) - 必填
类型 (Type) - 可选
字段1 (Field1) - 可选
字段2 (Field2) - 可选
字段3 (Field3) - 可选
字段4 (Field4) - 可选
字段5 (Field5) - 可选
备注 (Notes) - 可选
```

## 🔧 自定义模板

### 创建自定义模板

您可以基于现有模板创建自定义模板：

1. **选择基础模板**：选择最接近您需求的模板
2. **添加字段**：根据需要添加自定义字段
3. **设置属性**：配置字段类型、是否必填、是否保护
4. **保存模板**：保存为自定义模板供以后使用

### 字段类型说明

- **文本 (Text)**：普通文本信息
- **密码 (Password)**：受保护的敏感信息
- **邮箱 (Email)**：邮箱地址格式验证
- **网址 (URL)**：网址格式验证
- **数字 (Number)**：数字格式验证
- **日期 (Date)**：日期格式验证
- **多行文本 (Textarea)**：长文本内容

### 安全等级分类

- **公开信息**：标题、类型、备注等
- **个人信息**：姓名、地址、电话等
- **敏感信息**：密码、密钥、证件号等
- **机密信息**：私钥、种子、PIN码等

## 📋 使用建议

### 模板选择原则

1. **按用途选择**：根据信息类型选择合适的模板
2. **考虑安全性**：敏感信息选择保护级别高的模板
3. **便于管理**：相似信息使用同一模板便于分类
4. **灵活扩展**：预留扩展字段满足未来需求

### 填写最佳实践

1. **完整填写**：尽量填写所有相关字段
2. **定期更新**：及时更新过期信息
3. **合理分类**：使用模板分类功能
4. **备份重要**：重要信息建议备份

---

**合理使用模板，让密码管理更高效！** 📝

> 模板系统会持续优化，如有新的模板需求，欢迎反馈建议。 
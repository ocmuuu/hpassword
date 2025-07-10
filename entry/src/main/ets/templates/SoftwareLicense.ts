import { CategoryTemplate } from './TemplateTypes';

export const SoftwareLicenseTemplate: CategoryTemplate = {
  name: '软件许可证',
  desc: '操作系统或应用软件的序列号、授权邮箱及版本信息',
  fields: [
    { key: 'Title', label: '软件名称' },
    { key: 'Version', label: '版本' },
    { key: 'LicenseKey', label: '密钥', protected: true },
    { key: 'RegisteredEmail', label: '授权邮箱' },
    { key: 'Website', label: '官方网站' },
    { key: 'PurchaseDate', label: '购买日期' },
    { key: 'ExpiryDate', label: '过期日期' },
    { key: 'MaxDevices', label: '最大设备数' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: 'Windows 11 Pro',
      Version: '21H2',
      LicenseKey: 'A1234-XXXXX-XXXXX-XXXXX-XXXXX',
      RegisteredEmail: 'user@example.com',
      Website: 'https://www.microsoft.com/windows',
      PurchaseDate: '2023-10-01',
      ExpiryDate: '永久',
      MaxDevices: '1'
    }
  ]
}; 
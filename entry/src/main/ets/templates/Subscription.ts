import { CategoryTemplate } from './TemplateTypes';

export const SubscriptionTemplate: CategoryTemplate = {
  name: '会员订阅',
  desc: '付费订阅服务账号、套餐及下一次扣费日期，轻松管理续费',
  fields: [
    { key: 'Title', label: '服务名称' },
    { key: 'UserName', label: '登录账号' },
    { key: 'Password', label: '密码', protected: true },
    { key: 'RenewDate', label: '下次扣费日期' },
    { key: 'Plan', label: '套餐' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '阿里云盘',
      UserName: 'bob@example.com',
      Password: 'Netfl!x2024',
      RenewDate: '2024-08-01',
      Plan: 'Premium',
      Notes: '自动扣信用卡'
    }
  ]
}; 
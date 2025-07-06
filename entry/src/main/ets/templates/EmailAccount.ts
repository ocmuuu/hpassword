import { CategoryTemplate } from './TemplateTypes';

export const EmailAccountTemplate: CategoryTemplate = {
  name: '邮箱账户',
  desc: '各类电子邮箱登录凭据及 SMTP/IMAP 服务器等配置参数',
  fields: [
    { key: 'Title', label: '邮箱名称' },
    { key: 'UserName', label: '邮箱地址' },
    { key: 'Password', label: '邮箱密码', protected: true },
    { key: 'SMTP', label: 'SMTP 服务器' },
    { key: 'IMAP', label: 'IMAP 服务器' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: 'QQ 邮箱',
      UserName: '123456@qq.com',
      Password: 'Mail@1234',
      SMTP: 'smtp.qq.com',
      IMAP: 'imap.qq.com',
      Notes: '需开启授权码'
    }
  ]
}; 
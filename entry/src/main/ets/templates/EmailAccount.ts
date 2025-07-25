import { CategoryTemplate } from './TemplateTypes';

export const EmailAccountTemplate: CategoryTemplate = {
  name: '邮箱账户',
  desc: '各类电子邮箱登录凭据及 SMTP/IMAP 服务器等配置参数',
  fields: [
    { key: 'Title', label: '邮箱名称' },
    { key: 'UserName', label: '邮箱地址' },
    { key: 'Password', label: '邮箱密码', protected: true },
    { key: 'SMTP', label: 'SMTP 服务器' },
    { key: 'SMTPPort', label: 'SMTP 端口' },
    { key: 'IMAP', label: 'IMAP 服务器' },
    { key: 'IMAPPort', label: 'IMAP 端口' },
    { key: 'POP3', label: 'POP3 服务器' },
    { key: 'POP3Port', label: 'POP3 端口' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: 'QQ 邮箱',
      UserName: '123456@qq.com',
      Password: 'Mail@1234',
      SMTP: 'smtp.qq.com',
      SMTPPort: '465',
      IMAP: 'imap.qq.com',
      IMAPPort: '993',
      POP3: 'pop.qq.com',
      POP3Port: '995',
      Notes: '需开启授权码'
    }
  ]
}; 
import { CategoryTemplate } from './TemplateTypes';

export const LoginTemplate: CategoryTemplate = {
  name: '登录密码',
  desc: '网站、APP 的账号密码及二次验证信息，用于常规在线登录',
  fields: [
    { key: 'Title', label: '名称' },
    { key: 'UserName', label: '用户名' },
    { key: 'Email', label: '绑定邮箱' },
    { key: 'Password', label: '密码', protected: true },
    { key: 'URL', label: '网址' },
    { key: 'TOTP', label: '动态验证码' },
    { key: 'RecoveryKey', label: '恢复密钥', protected: true },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: 'Github',
      UserName: 'octocat',
      Email: 'octocat@github.com',
      Password: 'P@ssw0rd!',
      URL: 'https://github.com/login',
      TOTP: 'JBSWY3DPEHPK3PXP',
      RecoveryKey: '1234-5678-90AB-CDEF',
      Notes: '已开启 2FA'
    },
    {
      Title: '淘宝',
      UserName: 'alice@example.com',
      Email: 'alice@example.com',
      Password: 'Taobao@2024',
      URL: 'https://login.taobao.com',
      Notes: '手机短信二次验证'
    }
  ]
}; 
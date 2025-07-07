import { CategoryTemplate } from './TemplateTypes';

export const PaymentAccountTemplate: CategoryTemplate = {
  name: '支付账户',
  desc: '支付宝、微信支付、云闪付等第三方支付钱包的登录与支付口令信息',
  fields: [
    { key: 'Title', label: '账户名称' },
    { key: 'UserName', label: '登录邮箱/手机号' },
    { key: 'Password', label: '登录密码', protected: true },
    { key: 'PayPassword', label: '支付密码', protected: true },
    { key: 'RealName', label: '实名认证姓名' },
    { key: 'Phone', label: '绑定手机号' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '支付宝',
      UserName: '138****8888',
      Password: 'AliLogin2024',
      PayPassword: '******',
      RealName: '张三',
      Phone: '13800138888',
      Notes: '已绑定 U 盾'
    }
  ]
}; 
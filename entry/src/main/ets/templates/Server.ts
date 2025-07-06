import { CategoryTemplate } from './TemplateTypes';

export const ServerTemplate: CategoryTemplate = {
  name: '服务器',
  desc: 'VPS、物理机等服务器的主机地址、端口和 SSH/RDP 登录凭据',
  fields: [
    { key: 'Title', label: '主机名' },
    { key: 'Host', label: 'IP / 域名' },
    { key: 'Port', label: '端口' },
    { key: 'UserName', label: '用户名' },
    { key: 'Password', label: '密码', protected: true },
    { key: 'Protocol', label: '协议(SSH/RDP)' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '阿里云香港',
      Host: '47.88.xx.xx',
      Port: '22',
      UserName: 'root',
      Password: 'AliCloud@2024',
      Protocol: 'SSH'
    }
  ]
}; 
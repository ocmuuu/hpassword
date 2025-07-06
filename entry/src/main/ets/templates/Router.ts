import { CategoryTemplate } from './TemplateTypes';

export const RouterTemplate: CategoryTemplate = {
  name: '无线路由器',
  desc: '路由器/交换机的管理后台及 Wi-Fi SSID 与密码',
  fields: [
    { key: 'Title', label: '设备型号' },
    { key: 'Host', label: '管理地址' },
    { key: 'UserName', label: '用户名' },
    { key: 'Password', label: '密码', protected: true },
    { key: 'WiFi', label: 'Wi-Fi SSID' },
    { key: 'WiFiPassword', label: 'Wi-Fi 密码', protected: true },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '华硕 AX86U',
      Host: '192.168.50.1',
      UserName: 'admin',
      Password: 'Router@123',
      WiFi: 'MyHome',
      WiFiPassword: 'WifiP@ss'
    }
  ]
}; 
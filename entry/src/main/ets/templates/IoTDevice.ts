import { CategoryTemplate } from './TemplateTypes';

export const IoTDeviceTemplate: CategoryTemplate = {
  name: 'IoT 设备',
  desc: '智能家居或传感器等设备的地址、登录名和控制口令',
  fields: [
    { key: 'Title', label: '设备名称' },
    { key: 'Host', label: '地址/IP' },
    { key: 'UserName', label: '用户名' },
    { key: 'Password', label: '密码', protected: true },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '米家空调伴侣',
      Host: '192.168.1.90',
      UserName: 'admin',
      Password: 'mi@home'
    }
  ]
}; 
import { CategoryTemplate } from './TemplateTypes';

export const DatabaseTemplate: CategoryTemplate = {
  name: '数据库',
  desc: 'MySQL、PostgreSQL、MongoDB 等数据库的连接信息及用户凭据',
  fields: [
    { key: 'Title', label: '实例名' },
    { key: 'Type', label: '类型' },
    { key: 'Host', label: '主机' },
    { key: 'Port', label: '端口' },
    { key: 'DBName', label: '数据库名' },
    { key: 'UserName', label: '用户名' },
    { key: 'Password', label: '密码', protected: true },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '生产 MySQL',
      Type: 'MySQL',
      Host: '10.0.0.5',
      Port: '3306',
      DBName: 'prod_db',
      UserName: 'admin',
      Password: 'StrongPwd!'
    }
  ]
}; 
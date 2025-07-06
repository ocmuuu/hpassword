import { CategoryTemplate } from './TemplateTypes';

export const VehicleInfoTemplate: CategoryTemplate = {
  name: '车辆信息',
  desc: '车辆 VIN、车牌、保险到期等车辆相关重要信息',
  fields: [
    { key: 'Title', label: '车辆名称' },
    { key: 'VIN', label: 'VIN' },
    { key: 'Plate', label: '车牌号' },
    { key: 'Insurance', label: '保险到期' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '特斯拉 Model 3',
      VIN: 'LRW3E7EK1NC111111',
      Plate: '京A·12345',
      Insurance: '2025-04-06'
    }
  ]
}; 
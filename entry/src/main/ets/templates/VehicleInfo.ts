import { CategoryTemplate } from './TemplateTypes';

export const VehicleInfoTemplate: CategoryTemplate = {
  name: '车辆信息',
  desc: '车辆 VIN、车牌、保险到期等车辆相关重要信息',
  fields: [
    { key: 'Title', label: '车辆名称' },
    { key: 'Brand', label: '品牌' },
    { key: 'Model', label: '型号' },
    { key: 'VIN', label: 'VIN' },
    { key: 'Plate', label: '车牌号' },
    { key: 'Color', label: '颜色' },
    { key: 'PurchaseDate', label: '购买日期' },
    { key: 'Insurance', label: '保险到期' },
    { key: 'MaintenanceDate', label: '下次保养日期' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '特斯拉 Model 3',
      Brand: '特斯拉',
      Model: 'Model 3',
      VIN: 'LRW3E7EK1NC111111',
      Plate: '京A·12345',
      Color: '珍珠白',
      PurchaseDate: '2023-06-15',
      Insurance: '2025-04-06',
      MaintenanceDate: '2024-08-15'
    }
  ]
}; 
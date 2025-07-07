/**
 * KDF轮数预设值 - 定义不同安全级别
 */
export interface KdfRoundsPreset {
  name: string;
  rounds: number;
  description: string;
  estimatedTime: string;
}

/**
 * 默认KDF轮数
 */
export const DEFAULT_KDF_ROUNDS = 60000;

/**
 * KDF轮数预设值
 */
export const KDF_ROUNDS_PRESETS: KdfRoundsPreset[] = [
  {
    name: '快速',
    rounds: 10000,
    description: '基础安全级别，适合测试',
    estimatedTime: '< 1秒'
  },
  {
    name: '标准',
    rounds: 60000,
    description: '推荐的安全级别',
    estimatedTime: '1-2秒'
  },
  {
    name: '高',
    rounds: 100000,
    description: '高安全级别',
    estimatedTime: '2-3秒'
  },
  {
    name: '极高',
    rounds: 600000,
    description: '极高安全级别，计算时间较长',
    estimatedTime: '10-30秒'
  }
];

/**
 * 获取安全级别名称
 */
export function getSecurityLevelName(rounds: number): string {
  const preset = KDF_ROUNDS_PRESETS.find(p => p.rounds === rounds);
  return preset ? preset.name : '自定义';
}

/**
 * 获取安全级别描述
 */
export function getSecurityLevelDescription(rounds: number): string {
  const preset = KDF_ROUNDS_PRESETS.find(p => p.rounds === rounds);
  return preset ? preset.description : `自定义轮数: ${rounds}`;
}

/**
 * 验证KDF轮数是否有效
 */
export function validateKdfRounds(rounds: number): boolean {
  return rounds > 0 && rounds <= 10000000; // 最大1000万轮
} 
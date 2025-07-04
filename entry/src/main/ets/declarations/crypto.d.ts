declare module 'crypto' {
  export function createHash(algorithm: string): {
    update(data: ArrayBuffer | Uint8Array): { digest(): Uint8Array };
    digest(): Uint8Array;
  };
  export function createHmac(algorithm: string, key: Uint8Array): {
    update(data: Uint8Array): { digest(): Uint8Array };
    digest(): Uint8Array;
  };
  export function randomBytes(size: number): Uint8Array;
  export function createCipheriv(algorithm: string, key: Uint8Array, iv: Uint8Array): {
    update(data: Uint8Array): Uint8Array;
    final(): Uint8Array;
  };
  export function createDecipheriv(algorithm: string, key: Uint8Array, iv: Uint8Array): {
    update(data: Uint8Array): Uint8Array;
    final(): Uint8Array;
  };
} 
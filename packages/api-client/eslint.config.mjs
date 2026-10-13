import tsParser from '@typescript-eslint/parser';

const config = [
  {
    files: ['**/*.ts'],
    ignores: ['dist/**'],
    languageOptions: { parser: tsParser },
  },
];

export default config;

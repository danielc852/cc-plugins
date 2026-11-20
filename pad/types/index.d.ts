export type PadIsActive = boolean
export type PadTask = string

declare module 'claude-code' {
  interface PluginState {
    pad: { isActive: PadIsActive; task: PadTask }
  }
}

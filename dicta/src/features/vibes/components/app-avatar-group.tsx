interface AppAvatarGroupProps {
  icons: string[]
}

export function AppAvatarGroup({ icons }: AppAvatarGroupProps) {
  return (
    <div className="flex -space-x-2.5">
      {icons.map((icon, i) => (
        <div
          key={i}
          className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 bg-card border-2 border-border/60 shadow-sm"
          style={{ zIndex: icons.length - i }}
        >
          <div className="w-full h-full rounded-full bg-muted/30 flex items-center justify-center">
            <img src={icon} alt="" className="w-5 h-5 object-contain" />
          </div>
        </div>
      ))}
    </div>
  )
}

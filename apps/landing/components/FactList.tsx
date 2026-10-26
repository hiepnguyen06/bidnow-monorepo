export interface Fact {
  label: string
  value: string
}

/** A row of mono label/value pairs under a hairline, for the dark hero. */
export function FactList({ facts }: { facts: readonly Fact[] }) {
  return (
    <dl className="mt-16 grid grid-cols-2 gap-x-6 border-t border-[var(--color-border-default)] md:mt-20 md:grid-cols-4">
      {facts.map(({ label, value }) => (
        <div key={label} className="pb-2 pt-6">
          <dt className="font-mono text-[length:var(--font-size-xs)] uppercase text-muted-foreground">{label}</dt>
          <dd className="mt-2 font-mono text-[length:var(--font-size-xl)] font-medium leading-tight sm:text-[length:var(--font-size-2xl)]">
            {value}
          </dd>
        </div>
      ))}
    </dl>
  )
}

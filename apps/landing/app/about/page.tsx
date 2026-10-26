import type { Metadata } from 'next'
import { ArrowUpRight } from 'lucide-react'
import { Card } from '@/components/Card'
import { LinkButton } from '@/components/LinkButton'
import { PageHero } from '@/components/PageHero'
import { Section, SectionHeading } from '@/components/home/Section'
import { BUILT, DEVELOPERS, NOT_BUILT, OUT_OF_SCOPE, STACK, githubUrl, initials } from '@/lib/about'
import { DOCS_URL, REPO_URL } from '@/lib/site'

export const metadata: Metadata = {
  title: 'About',
  description: 'Project status, tech stack and the two developers behind BidNow.',
}

export default function AboutPage() {
  return (
    <>
      <PageHero
        eyebrow="About"
        title="An auction platform, built in the open by two developers."
        description="BidNow is a full-stack project: a Next.js app, a Spring Boot microservice backend and an AWS deployment in Terraform, all in one monorepo with its design documents alongside the code."
      />

      <Section id="status">
        <SectionHeading eyebrow="Project status" title="What works today, and what is next." />
        <div className="grid items-start gap-5 md:grid-cols-2">
          <Card className="p-7">
            <h3 className="flex items-center gap-2 font-semibold">
              <span className="size-2.5 rounded-full bg-[var(--color-text-brand)]" aria-hidden="true" />
              {BUILT.title}
            </h3>
            <ul className="mt-4 grid list-disc gap-2 pl-5 leading-relaxed">
              {BUILT.items.map((item) => <li key={item}>{item}</li>)}
            </ul>
          </Card>
          <Card className="border-[var(--color-warning-default)] bg-[var(--color-warning-subtle)] p-7">
            <h3 className="flex items-center gap-2 font-semibold">
              <span className="size-2.5 rounded-full bg-[var(--color-warning-default)]" aria-hidden="true" />
              {NOT_BUILT.title}
            </h3>
            <ul className="mt-4 grid list-disc gap-2 pl-5 leading-relaxed">
              {NOT_BUILT.items.map((item) => <li key={item}>{item}</li>)}
            </ul>
            <p className="mt-4 text-sm leading-relaxed text-muted-foreground">{OUT_OF_SCOPE}</p>
          </Card>
        </div>
      </Section>

      <Section id="stack" tinted>
        <SectionHeading eyebrow="Tech stack" title="What it is built with." />
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          {STACK.map(({ title, items }) => (
            <section key={title} aria-labelledby={`stack-${title}`} className="rounded-xl border border-[var(--color-border-default)] bg-card p-6">
              <h3 id={`stack-${title}`} className="font-display text-[length:var(--font-size-lg)] font-medium">
                {title}
              </h3>
              <ul className="mt-4">
                {items.map(({ name, role }) => (
                  <li key={name} className="flex justify-between gap-4 border-t border-[var(--color-border-default)] py-2.5 text-sm">
                    <span className="font-medium">{name}</span>
                    <span className="text-right text-muted-foreground">{role}</span>
                  </li>
                ))}
              </ul>
            </section>
          ))}
        </div>
      </Section>

      <Section id="team">
        <SectionHeading eyebrow="Developers" title="Built by" />
        <ul className="grid max-w-3xl gap-4 sm:grid-cols-2">
          {DEVELOPERS.map(({ name, handle }) => (
            <li key={handle}>
              <a
                href={githubUrl(handle)}
                target="_blank"
                rel="noopener noreferrer"
                className="group flex items-center gap-4 rounded-xl border border-[var(--color-border-default)] bg-card px-6 py-5 transition-[border-color] duration-[var(--duration-tesla)] ease-[var(--ease-tesla)] hover:border-[var(--color-text-brand)]"
              >
                <span
                  aria-hidden="true"
                  className="flex size-12 shrink-0 items-center justify-center rounded-full bg-accent font-display text-lg font-medium text-accent-foreground"
                >
                  {initials(name)}
                </span>
                <span className="flex min-w-0 flex-col">
                  <span className="font-display text-[length:var(--font-size-lg)] font-medium">{name}</span>
                  <span className="flex items-center gap-1 truncate font-mono text-[length:var(--font-size-xs)] text-[var(--color-text-brand)]">
                    github.com/{handle}
                    <ArrowUpRight className="size-3.5 shrink-0" aria-hidden="true" />
                    <span className="sr-only">(opens in a new tab)</span>
                  </span>
                </span>
              </a>
            </li>
          ))}
        </ul>
      </Section>

      <section className="dark bg-[var(--color-brand-900)] text-foreground">
        <div className="mx-auto flex w-full max-w-[var(--container-xl)] flex-wrap items-center justify-between gap-8 px-4 py-16 sm:px-6">
          <div className="min-w-0 flex-[1_1_480px]">
            <h2 className="font-display text-[length:var(--font-size-2xl)] font-medium leading-snug">
              Read the code and the reasoning behind it.
            </h2>
            <p className="mt-3 text-muted-foreground">
              Requirements, business decisions, flow diagrams and database schemas live in the repository&apos;s docs folder.
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <LinkButton href={REPO_URL}>View the source</LinkButton>
            <LinkButton href={DOCS_URL} variant="outline-dark">Browse the docs</LinkButton>
          </div>
        </div>
      </section>
    </>
  )
}

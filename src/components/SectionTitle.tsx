import { Text } from '@/components/ui/text'
import type { PropsWithChildren, SVGProps } from 'react'

export default function SectionTitle({
	children,
	Icon,
	CTA,
}: PropsWithChildren<{
	Icon?: (
		props: SVGProps<SVGSVGElement> & {
			variant: 'color' | 'monochrome'
		},
	) => JSX.Element
	CTA?: JSX.Element | null
}>) {
	return (
		<Text
			level="h2"
			as="h2"
			// This complicated `pl` is to align the text with the page padding, leaving the icon to the left of it
			className="pl-pageX pr-pageX xl:pl-[calc(var(--page-padding-x)_-_2.625rem)] flex gap-1 flex-col xl:flex-row xl:items-center xl:gap-2.5"
		>
			{Icon && <Icon variant="color" className="w-8" />}
			{children}
			{CTA && <div className="flex-1 xl:text-right">{CTA}</div>}
		</Text>
	)
}

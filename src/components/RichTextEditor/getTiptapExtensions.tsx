import { cn } from '@/utils/cn'
import Link from '@tiptap/extension-link'
import Placeholder from '@tiptap/extension-placeholder'
import type { Extensions } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import type { richTextEditorTheme } from './RichTextEditor.theme'

/**
 * Does not include CharacterCount extension because it breaks server actions.
 */
export function getTiptapExtensions({
	classes,
	placeholder,
}: {
	classes: ReturnType<typeof richTextEditorTheme>
	placeholder?: string
}): Extensions {
	return [
		StarterKit.configure({
			bulletList: {
				keepMarks: true,
				HTMLAttributes: {
					class: classes.tiptapListUl(),
				},
			},
			orderedList: {
				keepMarks: true,
				HTMLAttributes: {
					class: classes.tiptapListOl(),
				},
			},
			bold: {
				HTMLAttributes: {
					class: classes.tiptapBold(),
				},
			},
			italic: {
				HTMLAttributes: {
					class: classes.tiptapItalic(),
				},
			},
			strike: {
				HTMLAttributes: {
					class: classes.tiptapStrikethrough(),
				},
			},
		}),
		Placeholder.configure({
			placeholder: placeholder || '',
			emptyEditorClass: cn(
				'tiptap-placeholder',
				classes.placeholder(),
			) as string,
		}),
		Link.configure({
			openOnClick: false,
			HTMLAttributes: {
				class: classes.tiptapLink(),
			},
		}),
	]
}

'use client'

import { updateProfileAction } from '@/actions/updateProfile'
import UserAvatar from '@/components/UserAvatar'
import Field from '@/components/forms/Field'
import HandleInput from '@/components/forms/HandleInput'
import ImageInput from '@/components/forms/ImageInput'
import RichTextInput from '@/components/forms/RichTextInput'
import TwoColumnFields from '@/components/forms/TwoColumnFields'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Text } from '@/components/ui/text'
import { useToast } from '@/components/ui/use-toast'
import type { ProfilePageData } from '@/queries'
import {
	ImageDBToFormTransformer,
	ProfileData,
	type ProfileDataForDB,
	type ProfileDataInForm,
	RichText,
} from '@/schemas'
import { getChangedObjectSubset } from '@/utils/diffs'
import { effectSchemaResolverResolver } from '@/utils/effectSchemaResolver'
import { Schema } from '@effect/schema'
import { Either } from 'effect'
import { useMemo, useState } from 'react'
import {
	FormProvider,
	type SubmitHandler,
	useForm,
	useFormContext,
} from 'react-hook-form'

export default function ProfileForm({
	profile: profileInDb,
}: { profile: ProfilePageData }) {
	const toast = useToast()
	const [status, setStatus] = useState<'idle' | 'submitting'>('idle')

	const initialValue = useMemo(() => {
		const photoForForm = Schema.decodeUnknownEither(ImageDBToFormTransformer)(
			profileInDb.photo,
		)
		const bioInDB = Schema.encodeUnknownEither(RichText)(profileInDb.bio)

		return {
			id: profileInDb.id,
			name: profileInDb.name,
			handle: profileInDb.handle,
			location: profileInDb.location || undefined,
			photo: Either.isRight(photoForForm) ? photoForForm.right : undefined,
			bio: Either.isRight(bioInDB) ? bioInDB.right : undefined,
		} as ProfileDataInForm
	}, [profileInDb])

	const form = useForm<ProfileDataInForm>({
		resolver: effectSchemaResolverResolver(ProfileData),
		criteriaMode: 'all',
		defaultValues: initialValue,
		mode: 'onBlur',
		disabled: status === 'submitting',
	})

	const onSubmit: SubmitHandler<ProfileDataInForm> = async (data, event) => {
		const decodedData = data as unknown as ProfileDataForDB

		const dataThatChanged = getChangedObjectSubset({
			prev: Schema.decodeSync(ProfileData)(initialValue),
			next: decodedData,
		})
		if (Object.keys(dataThatChanged).length === 0) {
			toast.toast({
				variant: 'default',
				title: 'Tudo certo, nada foi alterado',
			})
		}

		setStatus('submitting')
		const response = await updateProfileAction(dataThatChanged)
		if (response === true) {
			toast.toast({
				variant: 'default',
				title: 'Perfil editado com sucesso ✨',
			})
		} else {
			toast.toast({
				variant: 'destructive',
				title: 'Erro ao editar',
				description: 'Por favor, tente novamente.',
			})
		}
		setStatus('idle')
	}

	return (
		<main className="flex flex-wrap gap-8 px-pageX py-pageY">
			<FormProvider {...form}>
				<form
					onSubmit={form.handleSubmit(onSubmit)}
					className="space-y-4 max-w-4xl flex-1"
					aria-disabled={form.formState.disabled}
				>
					<Card>
						<CardHeader className="flex !flex-row items-center justify-between flex-wrap">
							<CardTitle>Modifique seu perfil</CardTitle>
							<Button type="submit" disabled={form.formState.disabled}>
								Salvar alterações
							</Button>
						</CardHeader>
						<CardContent className="space-y-6 @container">
							<TwoColumnFields>
								<Field
									form={form}
									name="name"
									label="Nome"
									description="O nome que você preferir que te chamem, sem formalidades"
									render={({ field }) => (
										<Input {...field} value={field.value || ''} type="text" />
									)}
								/>
								<Field
									form={form}
									name="location"
									label="Território ou localidade"
									render={({ field }) => (
										<Input {...field} value={field.value || ''} type="text" />
									)}
								/>
							</TwoColumnFields>
							<TwoColumnFields>
								<Field
									form={form}
									name="handle"
									label="Endereço do seu perfil no site"
									render={({ field }) => (
										<HandleInput field={field} path="pessoas" />
									)}
								/>
								<Field
									form={form}
									name="bio"
									label="Curiosidades sobre você"
									render={({ field }) => (
										<RichTextInput
											field={field}
											placeholder="O que te encanta na cozinha? O que te levou à agroecologia?"
										/>
									)}
								/>
							</TwoColumnFields>
							<Field
								form={form}
								name="photo"
								label="Fotinha!"
								description="Caso queira, claro. Pode ser de vegetais que cê gosta, inclusive ✨"
								render={({ field }) => (
									<ImageInput field={field} includeMetadata={false} />
								)}
							/>
						</CardContent>
					</Card>
				</form>
				<ProfilePreview />
			</FormProvider>
		</main>
	)
}

function ProfilePreview() {
	const form = useFormContext<ProfileDataInForm>()
	const name = form.watch('name') || 'SEM NOME'
	const [fallbackTone] = useState(() =>
		name.length % 2 === 0 ? ('primary' as const) : ('secondary' as const),
	)
	const location = form.watch('location')
	const photo = form.watch('photo.data')

	return (
		<div className="sticky top-0 space-y-2 pt-6">
			{name && (
				<div>
					<Text level="h2" as="h2" className="text-lg font-bold">
						Como vai aparecer no site:
					</Text>
				</div>
			)}
			<UserAvatar
				user={{
					name,
					location,
					photo,
				}}
				fallbackTone={fallbackTone}
				size="lg"
			/>
		</div>
	)
}

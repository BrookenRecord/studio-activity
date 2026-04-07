local Plugin = script:FindFirstAncestor("StudioActivity")

local Packages = Plugin.Packages
local Foundation = require(Packages.Foundation)
local React = require(Packages.React)
local ReactUtils = require(Packages.ReactUtils)

local View = Foundation.View
local Text = Foundation.Text

local createNextOrder = ReactUtils.createNextOrder

local e = React.createElement

type Step = {
	id: string,
	text: string,
	content: React.ReactNode,
}

type StepProps = Step & {
	index: number,
	LayoutOrder: number?,
}

local function Step(props: StepProps)
	local nextOrder = createNextOrder()

	return e(View, {
		tag = "size-full-0 auto-y row gap-medium",
		LayoutOrder = props.LayoutOrder,
	}, {
		StepLabel = e(View, {
			tag = "size-600-600 radius-circle bg-shift-100 row align-x-center align-y-center",
			LayoutOrder = nextOrder(),
		}, {
			Label = e(Text, {
				tag = "auto-xy text-body-small content-default",
				Text = tostring(props.index),
				LayoutOrder = nextOrder(),
			}),
		}),

		ContentBlock = e(View, {
			tag = "grow auto-y col gap-small padding-top-xsmall",
			LayoutOrder = nextOrder(),
		}, {
			StepText = e(Text, {
				tag = "size-full-0 auto-y text-label-small content-default text-align-x-left text-wrap",
				Text = props.text,
				LayoutOrder = nextOrder(),
			}),

			CustomContentWrapper = props.content and e(View, {
				tag = "size-full-0 auto-y col gap-small",
				LayoutOrder = nextOrder(),
			}, props.content),
		}),
	})
end

type Props = {
	steps: { Step },
	LayoutOrder: number?,
}

local function Steps(props: Props)
	local stepChildren: { React.ReactNode } = {}
	for index, step in props.steps do
		table.insert(
			stepChildren,
			e(Step, {
				key = step.id,
				id = step.id,
				text = step.text,
				content = step.content,

				index = index,
				LayoutOrder = index,
			})
		)
	end

	return e(View, {
		tag = "size-full-0 auto-y gap-medium padding-y-medium",
		LayoutOrder = props.LayoutOrder,
	}, stepChildren)
end

return Steps

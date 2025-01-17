function add_interaction!(fig, ax, abmplot)
    add_controls = abmplot.add_controls[]
    add_param_sliders = !isempty(abmplot.params[])

    if add_controls
        @assert !isnothing(ax) "Need `ax` to add model controls."
        stepclick, resetclick = add_controls!(fig, abmplot.abmobs[], abmplot.spu)
    else
        stepclick = resetclick = nothing
    end

    if add_controls && add_param_sliders
        @assert !isnothing(ax) "Need `ax` to add plots and parameter sliders."
        add_param_sliders!(fig, abmplot.abmobs[].model, abmplot.params[], resetclick)
    end

    return stepclick
end

"Initialize model control buttons."
function add_controls!(fig, abmobs, spu)

    model, agent_step!, model_step!, adata, mdata, adf, mdf, when =
    getfield.(Ref(abmobs), (:model, :agent_step!, :model_step!, :adata, :mdata, :adf, :mdf, :when))

    init_dataframes!(model[], adata, mdata, adf, mdf)
    collect_data!(model[], when, adata, mdata, adf, mdf, abmobs.s[])

    # Create new layout for control buttons
    controllayout = fig[end+1,:][1,1] = GridLayout(tellheight = true)

    # Add steps-per-update slider
    spu_slider = labelslider!(fig, "spu =", spu[]; tellwidth = true)
    controllayout[1, :] = spu_slider.layout
    speed = spu_slider.slider.value

    # Add sleep slider
    if model[].space isa Agents.ContinuousSpace
        _s, _v = 0:0.01:1, 0
    else
        _s, _v = 0:0.01:2, 1
    end
    sleep_slider = labelslider!(fig, "sleep =", _s, sliderkw = Dict(:startvalue => _v))
    controllayout[2, :] = sleep_slider.layout
    slep = sleep_slider.slider.value

    # Step button
    step = Button(fig, label = "step")
    on(step.clicks) do c
        Agents.step!(abmobs, speed[])
        collect_data!(model[], when[], adata, mdata, adf, mdf, abmobs.s[])
    end

    # Run button
    run = Button(fig, label = "run")
    isrunning = Observable(false)
    on(run.clicks) do c; isrunning[] = !isrunning[]; end
    on(run.clicks) do c
        @async while isrunning[]
            step.clicks[] = step.clicks[] + 1
            slep[] == 0 ? yield() : sleep(slep[])
            isopen(fig.scene) || break # crucial, ensures computations stop if closed window.
        end
    end

    # Reset button
    reset = Button(fig, label = "reset\nmodel")
    model0 = deepcopy(model[]) # backup initial model state
    on(reset.clicks) do c
        model[] = deepcopy(model0)
        s = 0 # reset step counter
        Agents.step!(model[], agent_step!, model_step!, s)
    end

    # Clear button
    clear = Button(fig, label = "clear\ndata")
    on(clear.clicks) do c
        abmobs.s[] = 0
        init_dataframes!(model[], adata, mdata, adf, mdf)
        collect_data!(model[], when, adata, mdata, adf, mdf, abmobs.s[])
    end

    # Layout buttons
    controllayout[3, :][:, 1] = MakieLayout.hbox!(step, run; tellwidth = false)
    controllayout[3, :][:, 2] = MakieLayout.hbox!(reset, clear; tellwidth = false)

    return step.clicks, reset.clicks
end

"Initialize agent and model dataframes."
function init_dataframes!(model, adata, mdata, adf, mdf)
    if !isnothing(adata)
        adf.val = Agents.init_agent_dataframe(model, adata)
    end

    if !isnothing(mdata)
        mdf.val = Agents.init_model_dataframe(model, mdata)
    end

    return nothing
end

function collect_data!(model, when, adata, mdata, adf, mdf, s)
    if Agents.should_we_collect(s, model, when)
        if !isnothing(adata)
            Agents.collect_agent_data!(adf[], model, adata, s)
            adf[] = adf[] # trigger Observable
        end
        if !isnothing(mdata)
            Agents.collect_model_data!(mdf[], model, mdata, s)
            mdf[] = mdf[] # trigger Observable
        end
    end
    return nothing
end

"Initialize parameter control sliders."
function add_param_sliders!(fig, model, params, resetclick)
    datalayout = fig[end,:][1,2] = GridLayout(tellheight = true)

    slidervals = Dict{Symbol, Observable}()
    for (i, (k, vals)) in enumerate(params)
        startvalue = has_key(model[].properties, k) ?
            get_value(model[].properties, k) : vals[1]
        sll = labelslider!(fig, string(k), vals; sliderkw = Dict(:startvalue => startvalue))
        slidervals[k] = sll.slider.value # directly add the observable
        datalayout[i, :] = sll.layout
    end

    # Update button
    update = Button(fig, label = "update")
    on(update.clicks) do c
        for (k, v) in pairs(slidervals)
            if has_key(model[].properties, k)
                set_value!(model[].properties, k, v[])
            else
                throw(KeyError("$k"))
            end
        end
    end
    datalayout[end+1, :] = MakieLayout.hbox!(update; tellwidth = false)
    # Ensure resetted model has new parameters
    on(resetclick) do c
        update.clicks[] = update.clicks[] + 1
    end
    return nothing
end

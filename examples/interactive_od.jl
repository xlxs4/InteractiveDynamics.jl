using InteractiveChaos, Makie, DynamicalSystems

i = 1
p_index = 1

systems = [(Systems.logistic(), 2.5, 4.0, "r"),
           (Systems.henon(), 0.8, 1.4, "a"),
           (Systems.standardmap(), 0.6, 1.2, "k")]

ds, p_min, p_max, parname = systems[2]

oddata = interactive_orbitdiagram(ds, p_index, p_min, p_max, i;
                                  parname = parname)

ps, us = scaleod(oddata)

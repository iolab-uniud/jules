using SimpleTraits

@traitdef HasDeltaCost{I,S,M}
@traitimpl HasDeltaCost{I,S,M} <- hasmethod(delta_cost, (I, S, M))

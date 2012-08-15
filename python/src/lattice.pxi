cimport lattice

cdef class Lattice:
    cdef lattice.Lattice* lattice

    def __cinit__(self):
        self.lattice = new lattice.Lattice()

    def __init__(self, inp):
        if isinstance(inp, tuple):
            self.lattice.resize(len(inp))
            for i, arcs in enumerate(inp):
                self[i] = arcs
        else:
            if isinstance(inp, unicode):
                inp = inp.encode('utf8')
            if not isinstance(inp, str):
                raise TypeError('cannot create lattice from %s' % type(inp))
            lattice.ConvertTextOrPLF(string(<char *>inp), self.lattice)

    def __dealloc__(self):
        del self.lattice

    def __getitem__(self, int index):
        if not 0 <= index < len(self):
            raise IndexError('lattice index out of range')
        arcs = []
        cdef vector[lattice.LatticeArc] arc_vector = self.lattice[0][index]
        cdef lattice.LatticeArc* arc
        cdef unsigned i
        for i in range(arc_vector.size()):
            arc = &arc_vector[i]
            label = unicode(TDConvert(arc.label).c_str(), 'utf8')
            arcs.append((label, arc.cost, arc.dist2next))
        return tuple(arcs)

    def __setitem__(self, int index, tuple arcs):
        if not 0 <= index < len(self):
            raise IndexError('lattice index out of range')
        cdef lattice.LatticeArc* arc
        for (label, cost, dist2next) in arcs:
            if isinstance(label, unicode):
                label = label.encode('utf8')
            arc = new lattice.LatticeArc(TDConvert(<char *>label), cost, dist2next)
            self.lattice[0][index].push_back(arc[0])
            del arc

    def __len__(self):
        return self.lattice.size()

    def __str__(self):
        return str(hypergraph.AsPLF(self.lattice[0], True).c_str())

    def __unicode__(self):
        return unicode(str(self), 'utf8')

    def __iter__(self):
        cdef unsigned i
        for i in range(len(self)):
            yield self[i]

    def todot(self):
        def lines():
            yield 'digraph lattice {'
            yield 'rankdir = LR;'
            yield 'node [shape=circle];'
            for i in range(len(self)):
                for label, weight, delta in self[i]:
                    yield '%d -> %d [label="%s"];' % (i, i+delta, label.replace('"', '\\"'))
            yield '%d [shape=doublecircle]' % len(self)
            yield '}'
        return '\n'.join(lines()).encode('utf8')

    def as_hypergraph(self):
        cdef Hypergraph result = Hypergraph.__new__(Hypergraph)
        result.hg = new hypergraph.Hypergraph()
        cdef bytes plf = str(self)
        hypergraph.ReadFromPLF(string(plf), result.hg)
        return result
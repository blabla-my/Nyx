from spec_lib.generators import regex
from spec_lib.graph_spec import Spec


def main():
    spec = Spec()
    value = spec.edge_type("value", "uint8_t")
    data = spec.data_vec("raw", spec.data_u8("byte"), (0, 16), [regex("A+")])
    spec.node_type("emit", outputs=[value], data=data)

    packed = spec.build_msgpack()
    nodes = packed[1]
    atomics = packed[3]

    assert len(nodes[0]) == 6, nodes[0]
    assert nodes[0][5] is False, nodes[0]

    vec = next(atom for atom in atomics if atom[0] == "Vec")
    assert len(vec) == 5, vec
    assert vec[4] == [["Regex", "A+"]], vec

    print("schema ok")


if __name__ == "__main__":
    main()

// Raging Loop's Assembly-CSharp declares two fields of UnityEngine.MovieTexture, a type Unity
// removed from the 2018.3 Android player (the Windows Mono reference assembly still has it), and
// IL2CPP aborts on the dangling type reference. No IL reads or writes those fields, so retyping
// them to System.Object is enough. Usage: movietexture-patch <Managed/Assembly-CSharp.dll>
using System;
using System.Linq;
using Mono.Cecil;

class P {
    static int Main(string[] a) {
        var asm = AssemblyDefinition.ReadAssembly(a[0]);
        int n = 0;
        foreach (var m in asm.Modules)
        foreach (var t in m.GetTypes())
        foreach (var f in t.Fields)
            if (f.FieldType.FullName.Contains("MovieTexture")) {
                Console.WriteLine($"patch {t.FullName}.{f.Name}: {f.FieldType.FullName} -> System.Object");
                f.FieldType = m.TypeSystem.Object;
                n++;
            }
        if (n == 0) { Console.WriteLine("nothing to patch"); return 0; }
        asm.Write(a[0] + ".new");
        asm.Dispose();
        System.IO.File.Move(a[0] + ".new", a[0], true);
        Console.WriteLine($"patched {n} field(s)");
        return 0;
    }
}

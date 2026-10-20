using Xunit;

// Los tests levantan hosts completos (WebApplicationFactory) y comparten el
// FirebaseApp estático del proceso: arrancar dos en paralelo hace que el
// segundo explote con "The default FirebaseApp already exists". Se serializa
// la suite (son pocos tests y corren en menos de un segundo).
[assembly: CollectionBehavior(DisableTestParallelization = true)]

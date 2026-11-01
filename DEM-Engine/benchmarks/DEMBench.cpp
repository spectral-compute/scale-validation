// Fixed-length, output-free versions of DEME's Mixer and RotatingDrum demos, for benchmarking.
//
// Usage: DEMBench <mixer|drum> <simulated seconds>
// Prints "BENCH <scene> init_s=<s> warmup_s=<s> run_s=<s> steps=<n>": init_s includes JIT
// compilation, and warmup_s is the first 1000 steps (the solver adapts its contact-detection
// frequency and bin size early on).

#include <DEM/API.h>
#include <DEM/HostSideHelpers.hpp>
#include <DEM/utils/Samplers.hpp>

#include <chrono>
#include <cstdlib>
#include <iostream>
#include <string>

using namespace deme;

static void setupMixer(DEMSolver& DEMSim) {
    DEMSim.SetNoForceRecord();
    auto mat_type_mixer = DEMSim.LoadMaterial({{"E", 1e8}, {"nu", 0.3}, {"CoR", 0.6}, {"mu", 0.5}, {"Crr", 0.0}});
    auto mat_type_granular = DEMSim.LoadMaterial({{"E", 1e8}, {"nu", 0.3}, {"CoR", 0.6}, {"mu", 0.2}, {"Crr", 0.0}});
    DEMSim.SetMaterialPropertyPair("mu", mat_type_mixer, mat_type_granular, 0.5);

    const double world_size = 1;
    const float chamber_height = world_size / 3.;
    const float fill_height = chamber_height;
    const float chamber_bottom = -world_size / 2.;
    const float fill_bottom = chamber_bottom + chamber_height;

    DEMSim.InstructBoxDomainDimension(world_size, world_size, world_size);
    DEMSim.InstructBoxDomainBoundingBC("all", mat_type_granular);
    auto walls = DEMSim.AddExternalObject();
    walls->AddCylinder(make_float3(0), make_float3(0, 0, 1), world_size / 2., mat_type_mixer, 0);

    auto mixer = DEMSim.AddWavefrontMeshObject((GET_DATA_PATH() / "mesh/internal_mixer.obj").string(), mat_type_mixer);
    mixer->Scale(make_float3(world_size / 2, world_size / 2, chamber_height));
    mixer->SetFamily(10);
    DEMSim.SetFamilyPrescribedAngVel(10, "0", "0", "3.14159");

    float granular_rad = 0.005;
    float mass = 2.6e3 * 5.5886717;
    float3 MOI = make_float3(2.928, 2.6029, 3.9908) * 2.6e3;
    auto template_granular =
        DEMSim.LoadClumpType(mass, MOI, GetDEMEDataFile("clumps/3_clump.csv"), mat_type_granular);
    template_granular->Scale(granular_rad);

    auto mixer_tracker = DEMSim.Track(mixer);
    HCPSampler sampler(3.f * granular_rad);
    float3 fill_center = make_float3(0, 0, fill_bottom + fill_height / 2);
    const float fill_radius = world_size / 2. - 2. * granular_rad;
    auto input_xyz = sampler.SampleCylinderZ(fill_center, fill_radius, fill_height / 2);
    DEMSim.AddClumps(template_granular, input_xyz);
    std::cout << "Total num of particles: " << input_xyz.size() << std::endl;

    DEMSim.SetInitTimeStep(5e-6);
    DEMSim.SetGravitationalAcceleration(make_float3(0, 0, -9.81));
    DEMSim.SetCDUpdateFreq(40);
    DEMSim.SetExpandSafetyAdder(2.0);
    DEMSim.SetCDNumStepsMaxDriftMultipleOfAvg(1.2);
    DEMSim.SetCDNumStepsMaxDriftAheadOfAvg(6);
    DEMSim.SetSortContactPairs(true);
    DEMSim.SetErrorOutVelocity(20.);
    DEMSim.SetErrorOutAvgContacts(50);
    DEMSim.SetAdaptiveBinSizeUpperProactivity(0.5);
    DEMSim.SetAdaptiveBinSizeLowerProactivity(0.15);
    DEMSim.Initialize();
    mixer_tracker->SetPos(make_float3(0, 0, chamber_bottom + chamber_height / 2.0));
}

static void setupDrum(DEMSolver& DEMSim) {
    DEMSim.DisableJitifyClumpTemplates();
    DEMSim.SetNoForceRecord();

    std::vector<float> radii = {1.0, 0.88, 0.64, 0.88, 0.64};
    std::vector<float3> relPos = {make_float3(0, 0, 0), make_float3(0, 0, 0.86), make_float3(0, 0, 1.44),
                                  make_float3(0, 0, -0.86), make_float3(0, 0, -1.44)};
    float mass = 2.6e3 * 4. / 3. * PI * 2 * 1 * 1;
    float3 MOI = make_float3(1. / 5. * mass * (1 * 1 + 2 * 2), 1. / 5. * mass * (1 * 1 + 2 * 2),
                             1. / 5. * mass * (1 * 1 + 1 * 1));
    float scaling = 0.01;

    auto mat_type_sand = DEMSim.LoadMaterial({{"E", 1e9}, {"nu", 0.3}, {"CoR", 0.6}, {"mu", 0.4}, {"Crr", 0.01}});
    auto mat_type_drum = DEMSim.LoadMaterial({{"E", 2e9}, {"nu", 0.3}, {"CoR", 0.6}, {"mu", 0.8}, {"Crr", 0.01}});
    DEMSim.SetMaterialPropertyPair("mu", mat_type_sand, mat_type_drum, 0.8);

    std::vector<float> this_radii(radii);
    std::vector<float3> this_relPos(relPos);
    for (auto& r : this_radii)
        r *= scaling;
    for (auto& p : this_relPos)
        p = p * scaling;
    auto clump_type = DEMSim.LoadClumpType(scaling * scaling * scaling * mass,
                                           scaling * scaling * scaling * scaling * scaling * MOI, this_radii,
                                           this_relPos, mat_type_sand);

    float3 CylCenter = make_float3(0, 0, 0);
    float3 CylAxis = make_float3(1, 0, 0);
    float CylRad = 2.0;
    float CylHeight = 1.0;
    float CylMass = 1.0;
    float CylParticleRad = 0.05;
    float IXX = CylMass * CylRad * CylRad;
    float IYY = (CylMass / 12) * (3 * CylRad * CylRad + CylHeight * CylHeight);
    auto Drum_particles = DEMCylSurfSampler(CylCenter, CylAxis, CylRad, CylHeight, CylParticleRad);
    auto Drum_template =
        DEMSim.LoadClumpType(CylMass, make_float3(IXX, IYY, IYY),
                             std::vector<float>(Drum_particles.size(), CylParticleRad), Drum_particles, mat_type_drum);

    float safe_delta = 0.03;
    float sample_halfheight = CylHeight / 2.0 - 3.0 * safe_delta;
    float sample_halfwidth = CylRad / 1.5;
    auto input_xyz =
        DEMBoxGridSampler(make_float3(0), make_float3(sample_halfheight, sample_halfwidth, sample_halfwidth),
                          scaling * std::cbrt(2.0) * 2.1, scaling * std::cbrt(2.0) * 2.1, scaling * 2 * 2.1);
    DEMSim.AddClumps(clump_type, input_xyz);
    std::cout << "Total num of particles: " << input_xyz.size() << std::endl;

    auto Drum = DEMSim.AddClumps(Drum_template, make_float3(0));
    unsigned int drum_family = 100;
    Drum->SetFamilies(drum_family);
    DEMSim.SetFamilyPrescribedAngVel(drum_family, "0.1", "0", "0");
    DEMSim.DisableContactBetweenFamilies(drum_family, drum_family);

    auto top_bot_planes = DEMSim.AddExternalObject();
    top_bot_planes->AddPlane(make_float3(CylHeight / 2. - safe_delta, 0, 0), make_float3(-1, 0, 0), mat_type_drum);
    top_bot_planes->AddPlane(make_float3(-CylHeight / 2. + safe_delta, 0, 0), make_float3(1, 0, 0), mat_type_drum);
    top_bot_planes->SetFamily(drum_family);

    DEMSim.InstructBoxDomainDimension(5, 5, 5);
    DEMSim.SetInitTimeStep(5e-6);
    DEMSim.SetGravitationalAcceleration(make_float3(0, 0, -9.8));
    DEMSim.SetCDNumStepsMaxDriftMultipleOfAvg(1.1);
    DEMSim.SetCDNumStepsMaxDriftAheadOfAvg(3);
    DEMSim.SetMaxVelocity(3.);
    DEMSim.SetInitBinNumTarget(5e5);
    DEMSim.Initialize();
}

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "Usage: DEMBench <mixer|drum> <simulated seconds>\n";
        return 2;
    }
    const std::string scene = argv[1];
    const double sim_time = std::atof(argv[2]);
    const double step_size = 5e-6;
    const double warmup_time = 1000 * step_size;

    using clock = std::chrono::steady_clock;
    auto seconds = [](clock::time_point a, clock::time_point b) { return std::chrono::duration<double>(b - a).count(); };

    DEMSolver DEMSim;
    DEMSim.SetVerbosity(INFO);
    auto t0 = clock::now();
    if (scene == "mixer") {
        setupMixer(DEMSim);
    } else if (scene == "drum") {
        setupDrum(DEMSim);
    } else {
        std::cerr << "Unknown scene " << scene << "\n";
        return 2;
    }
    auto t1 = clock::now();
    DEMSim.DoDynamicsThenSync(warmup_time);
    auto t2 = clock::now();
    DEMSim.DoDynamicsThenSync(sim_time);
    auto t3 = clock::now();

    DEMSim.ShowThreadCollaborationStats();
    DEMSim.ShowTimingStats();
    std::cout << "BENCH " << scene << " init_s=" << seconds(t0, t1) << " warmup_s=" << seconds(t1, t2)
              << " run_s=" << seconds(t2, t3) << " steps=" << (long)(sim_time / step_size + 0.5) << std::endl;
    return 0;
}

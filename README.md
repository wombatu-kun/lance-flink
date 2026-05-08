<p align="center">
  <img src="https://flink.apache.org/img/logo/png/1000/flink_squirrel_1000.png" alt="Flink Logo" width="100"/>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img width="257" alt="Lance Logo" src="https://user-images.githubusercontent.com/917119/199353423-d3e202f7-0269-411d-8ff2-e747e419e492.png">
</p>

<h1 align="center">Flink Connector Lance</h1>

<p align="center">
  <strong>Apache Flink Connector for Lance Vector Database</strong>
</p>

<p align="center">
  <a href="https://github.com/hashmapybx/flink-connector-lance/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-Apache%202.0-blue.svg" alt="License"/>
  </a>
  <a href="https://github.com/hashmapybx/flink-connector-lance/actions">
    <img src="https://img.shields.io/badge/build-passing-brightgreen.svg" alt="Build Status"/>
  </a>
  <img src="https://img.shields.io/badge/flink-1.16.1-orange.svg" alt="Flink Version"/>
  <img src="https://img.shields.io/badge/lance-0.23.3-purple.svg" alt="Lance Version"/>
  <img src="https://img.shields.io/badge/java-8+-red.svg" alt="Java Version"/>
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-documentation">Documentation</a> •
  <a href="#-contributing">Contributing</a>
</p>

---

## 📖 Overview

`flink-connector-lance` is a high-performance Apache Flink connector for [Lance](https://lancedb.github.io/lance/), a modern columnar data format optimized for machine learning workloads and vector search. This connector enables seamless integration between Flink's powerful stream/batch processing capabilities and Lance's efficient vector storage.

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔄 **Source & Sink** | Full read/write support for Lance datasets |
| 📊 **Table API & SQL** | Native Flink SQL DDL/DML support |
| 🔍 **Vector Search** | KNN search with L2, Cosine, Dot metrics |
| 📇 **Index Building** | IVF_PQ, IVF_HNSW, IVF_FLAT indexes |
| ✅ **Exactly-Once** | Checkpoint-based exactly-once semantics |
| 🎯 **Predicate Pushdown** | Filter pushdown for optimized reads |
| 📁 **Catalog Support** | Lance Catalog for metadata management |

## 🚀 Quick Start

### Prerequisites

- Java 8 or higher
- Apache Flink 1.16.x
- Maven 3.6+

### Maven Dependency

```xml
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-connector-lance</artifactId>
    <version>1.0.0-SNAPSHOT</version>
</dependency>
```

### Flink SQL Example

```sql
-- Create a Lance table
CREATE TABLE vectors (
    id BIGINT,
    content STRING,
    embedding ARRAY<FLOAT>
) WITH (
    'connector' = 'lance',
    'path' = '/data/vectors',
    'write.batch-size' = '1024'
);

-- Insert data
INSERT INTO vectors VALUES 
    (1, 'Hello World', ARRAY[0.1, 0.2, 0.3, 0.4]);

-- Query data
SELECT * FROM vectors WHERE id > 0;
```

### DataStream API Example

```java
// Read from Lance
LanceSource source = LanceSource.builder()
    .path("/data/vectors")
    .batchSize(1024)
    .columns(Arrays.asList("id", "embedding"))
    .rowType(rowType)
    .build();

DataStream<RowData> stream = env.addSource(source);

// Write to Lance
LanceSink sink = LanceSink.builder()
    .path("/data/output")
    .batchSize(1024)
    .writeMode(WriteMode.APPEND)
    .rowType(rowType)
    .build();

stream.addSink(sink);
```

## 📚 Documentation

### Table API / SQL

#### Create Catalog

```sql
CREATE CATALOG lance_catalog WITH (
    'type' = 'lance',
    'warehouse' = '/path/to/warehouse',
    'default-database' = 'default'
);

USE CATALOG lance_catalog;
```

#### Table Options

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `connector` | ✅ | - | Must be `lance` |
| `path` | ✅ | - | Lance dataset path |
| `read.batch-size` | ❌ | 1024 | Read batch size |
| `write.batch-size` | ❌ | 1024 | Write batch size |
| `write.mode` | ❌ | append | `append` or `overwrite` |
| `write.max-rows-per-file` | ❌ | 1000000 | Max rows per file |

### Vector Index Building

```java
LanceIndexBuilder builder = LanceIndexBuilder.builder()
    .datasetPath("/data/vectors")
    .columnName("embedding")
    .indexType(IndexType.IVF_PQ)
    .metricType(MetricType.L2)
    .numPartitions(256)
    .numSubVectors(16)
    .build();

builder.buildIndex();
```

#### Supported Index Types

| Index Type | Use Case | Parameters |
|------------|----------|------------|
| **IVF_PQ** | Large-scale, memory-efficient | `num_partitions`, `num_sub_vectors`, `num_bits` |
| **IVF_HNSW** | High recall, fast search | `num_partitions`, `m`, `ef_construction` |
| **IVF_FLAT** | Small datasets, exact search | `num_partitions` |

#### 📊 Index Selection Guide

| Scenario | Recommended Index | Reason |
|----------|------------------|--------|
| **< 100K vectors** | IVF_FLAT | High accuracy, acceptable performance |
| **100K - 10M vectors** | IVF_PQ | Good balance of accuracy and memory |
| **> 10M vectors** | IVF_PQ (tuned) | Optimize `num_partitions` and `num_sub_vectors` |
| **High recall required** | IVF_HNSW | Best accuracy, higher memory usage |
| **Memory constrained** | IVF_PQ | Most memory efficient |
| **Real-time search** | IVF_HNSW | Fastest query latency |

#### ⚙️ Index Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `index.type` | IVF_PQ | Index type: `IVF_PQ`, `IVF_HNSW`, `IVF_FLAT` |
| `index.column` | - | Vector column name for indexing |
| `index.num-partitions` | 256 | Number of IVF partitions |
| `index.num-sub-vectors` | 16 | PQ sub-vectors (IVF_PQ only) |
| `index.num-bits` | 8 | Bits per sub-vector (IVF_PQ only) |
| `index.m` | 16 | HNSW max connections (IVF_HNSW only) |
| `index.ef-construction` | 100 | HNSW build quality (IVF_HNSW only) |

#### 🔧 Index Building SQL Example

```sql
-- Create table with IVF_PQ index
CREATE TABLE doc_embeddings (
    doc_id BIGINT,
    title STRING,
    embedding ARRAY<FLOAT>
) WITH (
    'connector' = 'lance',
    'path' = '/data/embeddings',
    'index.type' = 'IVF_PQ',
    'index.column' = 'embedding',
    'index.num-partitions' = '256',
    'index.num-sub-vectors' = '16',
    'vector.metric' = 'COSINE'
);

-- Create table with IVF_HNSW index (high accuracy)
CREATE TABLE high_accuracy_vectors (
    id BIGINT,
    vector ARRAY<FLOAT>
) WITH (
    'connector' = 'lance',
    'path' = '/data/ha_vectors',
    'index.type' = 'IVF_HNSW',
    'index.column' = 'vector',
    'index.num-partitions' = '128',
    'index.m' = '32',
    'index.ef-construction' = '200',
    'vector.metric' = 'L2'
);
```

### Vector Search

```java
LanceVectorSearch search = LanceVectorSearch.builder()
    .datasetPath("/data/vectors")
    .columnName("embedding")
    .metricType(MetricType.COSINE)
    .nprobes(20)
    .build();

search.open();
List<SearchResult> results = search.search(queryVector, 10);
search.close();
```

#### Distance Metrics

| Metric | Description | Range |
|--------|-------------|-------|
| **L2** | Euclidean distance | [0, ∞) |
| **Cosine** | Cosine similarity | [-1, 1] |
| **Dot** | Inner product | (-∞, ∞) |

### Type Mapping

| Lance/Arrow Type | Flink Type |
|------------------|------------|
| Int8/16/32/64 | TINYINT/SMALLINT/INT/BIGINT |
| Float32/64 | FLOAT/DOUBLE |
| String | STRING |
| Boolean | BOOLEAN |
| Binary | BYTES |
| Date32 | DATE |
| Timestamp | TIMESTAMP |
| FixedSizeList\<Float\> | ARRAY\<FLOAT\> |

## 🏗️ Project Structure

```
flink-connector-lance/
├── src/main/java/org/apache/flink/connector/lance/
│   ├── LanceSource.java           # Source implementation
│   ├── LanceSink.java             # Sink with checkpointing
│   ├── LanceInputFormat.java      # Batch input format
│   ├── LanceIndexBuilder.java     # Vector index builder
│   ├── LanceVectorSearch.java     # KNN search
│   ├── config/
│   │   └── LanceOptions.java      # Configuration options
│   ├── converter/
│   │   ├── LanceTypeConverter.java
│   │   └── RowDataConverter.java
│   └── table/
│       ├── LanceDynamicTableFactory.java
│       ├── LanceDynamicTableSource.java
│       ├── LanceDynamicTableSink.java
│       ├── LanceCatalog.java
│       └── LanceVectorSearchFunction.java
└── src/test/java/                 # Unit & integration tests
```

## 🔧 Build

```bash
# Build without tests
mvn clean package -DskipTests

# Build with tests
mvn clean package

# Run tests only
mvn test
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📋 Roadmap

- [ ] Streaming CDC support
- [ ] Delta Lake interoperability
- [ ] Distributed index building
- [ ] GPU acceleration support
- [ ] Python Table API support

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Apache Flink](https://flink.apache.org/) - Stateful computations over data streams
- [LanceDB](https://lancedb.com/) - Modern columnar data format for ML
- [Apache Arrow](https://arrow.apache.org/) - Cross-language development platform

---

<p align="center">
  Made with ❤️ by the Flink Connector Lance Contributors
</p>

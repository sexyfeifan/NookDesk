import Foundation

struct BlogPost: Identifiable {
    var fileURL: URL
    var title: String
    var date: Date
    var draft: Bool
    var summary: String
    var tags: [String]
    var categories: [String]
    var pin: Bool
    var math: Bool
    var mathJax: Bool
    var isPrivate: Bool
    var searchable: Bool
    var cover: String
    var author: String
    var keywords: [String]
    var customTaxonomies: [String: [String]]
    var taxonomyWeights: [String: Int]
    var slug: String
    var urlPath: String
    var aliases: [String]
    var translationKey: String
    var frontMatterFormat: FrontMatterFormat
    var rawFrontMatter: String
    var body: String

    var id: String {
        fileURL.path
    }

    var fileName: String {
        fileURL.lastPathComponent
    }

    var displayFileName: String {
        fileURL.lastPathComponent
    }

    var usesPageBundle: Bool { false }

    var bundleDisplayName: String { "单文件" }

    // [NookDesk 修复] 增加 backend 参数，默认 .yaml 格式；
    // 当后端是 Astro 时用 .astro 格式，Hugo 用 .toml。
    static func empty(in contentURL: URL, backend: SSGBuildBackend? = nil) -> BlogPost {
        let file = contentURL.appendingPathComponent("new-post.md")
        // [NookDesk 修复] 根据后端类型选择默认 front matter 格式
        let defaultFormat: FrontMatterFormat
        if let backend {
            switch backend.displayName {
            case "Astro":
                defaultFormat = .astro
            case "Hugo":
                defaultFormat = .toml
            default:
                defaultFormat = .yaml
            }
        } else {
            defaultFormat = .yaml
        }
        return BlogPost(
            fileURL: file,
            title: "",
            date: Date(),
            draft: true,
            summary: "",
            tags: [],
            categories: [],
            pin: false,
            math: false,
            mathJax: false,
            isPrivate: false,
            searchable: true,
            cover: "",
            author: "",
            keywords: [],
            customTaxonomies: [:],
            taxonomyWeights: [:],
            slug: "",
            urlPath: "",
            aliases: [],
            translationKey: "",
            frontMatterFormat: defaultFormat,
            rawFrontMatter: "",
            body: ""
        )
    }
}

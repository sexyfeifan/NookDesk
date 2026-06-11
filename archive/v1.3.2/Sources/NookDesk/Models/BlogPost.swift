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

    static func empty(in contentURL: URL) -> BlogPost {
        let file = contentURL.appendingPathComponent("new-post.md")
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
            frontMatterFormat: .toml,
            rawFrontMatter: "",
            body: ""
        )
    }
}
